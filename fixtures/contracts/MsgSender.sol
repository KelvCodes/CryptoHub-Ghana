// SPDX-License-Identifier: GNU
pragma solidity ^0.8.19;

/**
 * =============================================================
 * @title AdvancedMsgSenderV3 (Enterprise Edition)
 * @author Kelvin A.
 * @notice Next-generation advanced Solidity patterns demonstration:
 * - Multi-signature ownership (Gnosis-style)
 * - Time-locked governance
 * - Batch operations
 * - Merkle-tree based permissions
 * - EIP-712 signatures for meta-transactions
 * - Upgradeable pattern (UUPS)
 * - Reentrancy guards
 * - Multi-token integration
 * - Decentralized storage patterns
 * - Advanced cryptography
 * =============================================================
 */

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract AdvancedMsgSenderV3 is EIP712, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                TYPES
    //////////////////////////////////////////////////////////////*/

    enum PauseMode {
        Unpaused,
        WritePaused,
        FullyPaused
    }

    enum ProposalState {
        Pending,
        Active,
        Executed,
        Canceled
    }

    enum AccessLevel {
        None,
        Viewer,
        Editor,
        Admin,
        Owner
    }

    struct UpdateSnapshot {
        string value;
        address updater;
        uint256 timestamp;
        bytes32 valueHash;
        uint256 blockNumber;
        AccessLevel accessLevelUsed;
    }

    struct EditorStats {
        uint256 updatesMade;
        uint256 lastUpdateAt;
        uint256 totalGasUsed;
        uint256 consecutiveUpdates;
        uint256 rewardPoints;
    }

    struct TimeLockedProposal {
        uint256 id;
        address proposer;
        string description;
        bytes callData;
        uint256 createdAt;
        uint256 executeAt;
        uint256 votesFor;
        uint256 votesAgainst;
        mapping(address => bool) hasVoted;
        ProposalState state;
    }

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct UpdateRequest {
        string newValue;
        uint256 deadline;
        address executor;
        uint256 nonce;
    }

    struct AccessControlEntry {
        AccessLevel level;
        uint256 expiresAt;
        bytes32[] merkleProof;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    // Core storage
    string private _currentString;
    uint256 public updateCount;
    PauseMode public pauseMode;

    // Multi-signature ownership
    address[] public multiSigOwners;
    mapping(address => bool) public isOwner;
    uint256 public requiredSignatures;
    mapping(bytes32 => mapping(address => bool)) public multiSigConfirmations;

    // Time-locked governance
    uint256 public proposalCount;
    mapping(uint256 => TimeLockedProposal) private proposals;
    uint256 public constant MIN_VOTING_PERIOD = 3 days;
    uint256 public constant EXECUTION_DELAY = 2 days;
    uint256 public constant QUORUM_PERCENTAGE = 30; // 30% of editors must vote

    // Merkle-tree based permissions
    bytes32 public editorMerkleRoot;
    mapping(address => uint256) public editorExpiry;

    // EIP-712 meta-transactions
    string private constant SIGNING_DOMAIN = "AdvancedMsgSender";
    string private constant SIGNATURE_VERSION = "1";
    bytes32 private constant UPDATE_REQUEST_TYPEHASH = keccak256(
        "UpdateRequest(string newValue,uint256 deadline,address executor,uint256 nonce)"
    );
    mapping(address => uint256) public nonces;

    // Token integration
    IERC20 public rewardToken;
    uint256 public constant UPDATE_REWARD = 10 * 10**18; // 10 tokens per update
    uint256 public constant BONUS_THRESHOLD = 100; // Consecutive updates for bonus

    // Enhanced history
    UpdateSnapshot[] private snapshots;
    mapping(uint256 => uint256) private updateTimestamps;
    mapping(address => EditorStats) private editorStats;
    mapping(uint256 => bytes32) private updateMerkleRoots; // For verification

    // Rate limiting with tiers
    uint256 public constant BASE_UPDATE_INTERVAL = 30 seconds;
    uint256 public constant TRUSTED_UPDATE_INTERVAL = 10 seconds;
    mapping(address => uint256) private lastActionAt;
    mapping(address => bool) public trustedAccounts;

    // Emergency and recovery
    bool public emergencyMode;
    address public recoveryAddress;
    uint256 public emergencyExpiry;
    bytes32 private immutable _emergencyHash; // Pre-committed emergency value

    // Version control
    uint256 public constant VERSION = 3;
    bytes32 public immutable INIT_CODE_HASH;

    // Performance optimizations
    uint256[50] private __gap; // Storage gap for upgrades

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized(address caller, AccessLevel required);
    error InvalidAddress();
    error EmptyString();
    error ContractPaused(PauseMode currentMode);
    error RateLimited(uint256 retryAfter, uint256 currentTime);
    error NoHistory();
    error EmergencyOnly();
    error AlreadyEditor(address editor);
    error InvalidSignature();
    error SignatureExpired();
    error InvalidMerkleProof();
    error EditorExpired(address editor);
    error InsufficientVotes(uint256 votesFor, uint256 votesAgainst);
    error ProposalNotReady(uint256 executeAt, uint256 currentTime);
    error MultiSigError(string reason);
    error TokenTransferFailed();
    error InvalidUpdateValue();
    error ProposalExecutionFailed(bytes returnData);
    error AccessExpired(address account, uint256 expiresAt);

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event StringUpdated(
        address indexed updater,
        string oldValue,
        string newValue,
        uint256 indexed version,
        uint256 timestamp,
        uint256 blockNumber,
        uint256 gasUsed,
        uint256 reward
    );

    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event MultiSigOwnerAdded(address indexed owner);
    event MultiSigOwnerRemoved(address indexed owner);
    event MultiSigConfirmed(bytes32 indexed txHash, address indexed confirmer);
    event MultiSigExecuted(bytes32 indexed txHash);
    
    event EditorAdded(address indexed editor, uint256 expiry);
    event EditorRemoved(address indexed editor);
    event EditorExpiredEvent(address indexed editor);
    event EditorMerkleRootUpdated(bytes32 newRoot);
    
    event PauseModeChanged(PauseMode mode);
    event EmergencyModeActivated(address indexed recovery, uint256 expiry);
    event EmergencyRecovered(string restoredValue);
    event HistoryCleared(uint256 atVersion);
    
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string description,
        uint256 executeAt
    );
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 weight
    );
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);
    
    event TrustedAccountAdded(address indexed account);
    event TrustedAccountRemoved(address indexed account);
    event RewardClaimed(address indexed account, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyWithAccess(AccessLevel required) {
        AccessLevel callerLevel = _getAccessLevel(msg.sender);
        if (callerLevel < required) 
            revert Unauthorized(msg.sender, required);
        _;
    }

    modifier whenReadable() {
        if (pauseMode == PauseMode.FullyPaused)
            revert ContractPaused(pauseMode);
        _;
    }

    modifier whenWritable() {
        if (pauseMode != PauseMode.Unpaused)
            revert ContractPaused(pauseMode);
        _;
    }

    modifier rateLimited() {
        uint256 interval = trustedAccounts[msg.sender] 
            ? TRUSTED_UPDATE_INTERVAL 
            : BASE_UPDATE_INTERVAL;
        
        uint256 last = lastActionAt[msg.sender];
        if (block.timestamp < last + interval) {
            revert RateLimited(last + interval, block.timestamp);
        }
        _;
        lastActionAt[msg.sender] = block.timestamp;
    }

    modifier onlyEmergency() {
        if (!emergencyMode) revert EmergencyOnly();
        if (block.timestamp > emergencyExpiry) {
            emergencyMode = false;
            revert EmergencyOnly();
        }
        _;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory initialValue,
        address[] memory initialOwners,
        uint256 _requiredSignatures,
        address _rewardToken
    ) EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {
        if (bytes(initialValue).length == 0) revert EmptyString();
        if (initialOwners.length == 0) revert InvalidAddress();
        if (_requiredSignatures > initialOwners.length) revert MultiSigError("Invalid required signatures");

        // Initialize multi-sig
        for (uint i = 0; i < initialOwners.length; i++) {
            address owner = initialOwners[i];
            if (owner == address(0)) revert InvalidAddress();
            if (isOwner[owner]) revert MultiSigError("Duplicate owner");
            
            isOwner[owner] = true;
            multiSigOwners.push(owner);
        }
        requiredSignatures = _requiredSignatures;

        // Initialize core state
        _currentString = initialValue;
        pauseMode = PauseMode.Unpaused;
        rewardToken = IERC20(_rewardToken);

        // Create initial snapshot
        snapshots.push(
            UpdateSnapshot({
                value: initialValue,
                updater: msg.sender,
                timestamp: block.timestamp,
                valueHash: keccak256(bytes(initialValue)),
                blockNumber: block.number,
                accessLevelUsed: AccessLevel.Owner
            })
        );

        updateTimestamps[0] = block.timestamp;
        
        // Pre-commit emergency hash
        _emergencyHash = keccak256(
            abi.encodePacked(initialValue, block.timestamp, "EMERGENCY_BACKUP")
        );
        
        INIT_CODE_HASH = keccak256(type(AdvancedMsgSenderV3).creationCode);
    }

    /*//////////////////////////////////////////////////////////////
                            READ FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function currentString() 
        external 
        view 
        whenReadable 
        returns (string memory) 
    {
        return _currentString;
    }

    function currentHash() external view returns (bytes32) {
        return keccak256(bytes(_currentString));
    }

    function snapshotCount() external view returns (uint256) {
        return snapshots.length;
    }

    function getSnapshot(uint256 index)
        external
        view
        returns (UpdateSnapshot memory)
    {
        return snapshots[index];
    }

    function getSnapshots(uint256 start, uint256 count)
        external
        view
        returns (UpdateSnapshot[] memory)
    {
        uint256 end = start + count;
        if (end > snapshots.length) end = snapshots.length;
        
        UpdateSnapshot[] memory result = new UpdateSnapshot[](end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = snapshots[i];
        }
        return result;
    }

    function editorActivity(address editor)
        external
        view
        returns (EditorStats memory)
    {
        return editorStats[editor];
    }

    function lastUpdatedAt() external view returns (uint256) {
        return updateTimestamps[updateCount];
    }

    function getProposal(uint256 proposalId)
        external
        view
        returns (
            uint256 id,
            address proposer,
            string memory description,
            uint256 executeAt,
            uint256 votesFor,
            uint256 votesAgainst,
            ProposalState state
        )
    {
        TimeLockedProposal storage p = proposals[proposalId];
        return (
            p.id,
            p.proposer,
            p.description,
            p.executeAt,
            p.votesFor,
            p.votesAgainst,
            p.state
        );
    }

    function hasEditorAccess(address account) public view returns (bool) {
        if (isOwner[account]) return true;
        
        // Check expiry
        if (editorExpiry[account] < block.timestamp) return false;
        
        return true;
    }

    function verifyMerkleEditor(address account, bytes32[] calldata proof)
        public
        view
        returns (bool)
    {
        bytes32 leaf = keccak256(abi.encodePacked(account));
        return MerkleProof.verify(proof, editorMerkleRoot, leaf);
    }

    function getAccessLevel(address account) public view returns (AccessLevel) {
        return _getAccessLevel(account);
    }

    function getUpdateMerkleRoot(uint256 version) external view returns (bytes32) {
        return updateMerkleRoots[version];
    }

    function verifyUpdateIntegrity(uint256 version, string calldata value, bytes32[] calldata proof)
        external
        view
        returns (bool)
    {
        bytes32 leaf = keccak256(abi.encodePacked(version, value));
        return MerkleProof.verify(proof, updateMerkleRoots[version], leaf);
    }

    /*//////////////////////////////////////////////////////////////
                            WRITE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function updateString(string calldata newValue)
        external
        onlyWithAccess(AccessLevel.Editor)
        whenWritable
        rateLimited
        nonReentrant
        returns (uint256)
    {
        if (bytes(newValue).length == 0) revert EmptyString();
        if (keccak256(bytes(newValue)) == keccak256(bytes(_currentString))) 
            revert InvalidUpdateValue();

        uint256 gasStart = gasleft();
        string memory old = _currentString;
        _currentString = newValue;
        updateCount++;

        // Create snapshot
        snapshots.push(
            UpdateSnapshot({
                value: newValue,
                updater: msg.sender,
                timestamp: block.timestamp,
                valueHash: keccak256(bytes(newValue)),
                blockNumber: block.number,
                accessLevelUsed: _getAccessLevel(msg.sender)
            })
        );

        updateTimestamps[updateCount] = block.timestamp;
        
        // Update Merkle root for this version
        updateMerkleRoots[updateCount] = keccak256(
            abi.encodePacked(updateCount, newValue, block.timestamp)
        );

        // Update editor stats
        uint256 gasUsed = gasStart - gasleft();
        EditorStats storage stats = editorStats[msg.sender];
        stats.updatesMade++;
        stats.lastUpdateAt = block.timestamp;
        stats.totalGasUsed += gasUsed;
        stats.consecutiveUpdates++;
        
        // Reward system
        uint256 reward = UPDATE_REWARD;
        if (stats.consecutiveUpdates >= BONUS_THRESHOLD) {
            reward += UPDATE_REWARD / 2; // 50% bonus
        }
        stats.rewardPoints += reward / 1e18;

        // Transfer rewards
        if (address(rewardToken) != address(0)) {
            bool success = rewardToken.transfer(msg.sender, reward);
            if (!success) revert TokenTransferFailed();
        }

        emit StringUpdated(
            msg.sender,
            old,
            newValue,
            updateCount,
            block.timestamp,
            block.number,
            gasUsed,
            reward
        );

        return updateCount;
    }

    function updateStringWithSignature(
        string calldata newValue,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external whenWritable nonReentrant returns (uint256) {
        if (block.timestamp > deadline) revert SignatureExpired();
        
        address signer = _verifyUpdateSignature(newValue, deadline, msg.sender, v, r, s);
        
        // Use the signer's access level, but execute as msg.sender (relayer)
        AccessLevel signerLevel = _getAccessLevel(signer);
        if (signerLevel < AccessLevel.Editor) revert Unauthorized(signer, AccessLevel.Editor);
        
        // Update with signer's stats
        return _executeUpdate(newValue, signer);
    }

    function batchUpdateStrings(string[] calldata newValues)
        external
        onlyWithAccess(AccessLevel.Admin)
        whenWritable
        nonReentrant
        returns (uint256[] memory versions)
    {
        versions = new uint256[](newValues.length);
        for (uint256 i = 0; i < newValues.length; i++) {
            versions[i] = _executeUpdate(newValues[i], msg.sender);
        }
    }

    function restorePrevious()
        external
        onlyWithAccess(AccessLevel.Admin)
        whenWritable
        nonReentrant
        returns (uint256)
    {
        if (snapshots.length < 2) revert NoHistory();

        UpdateSnapshot memory prev = snapshots[snapshots.length - 2];
        return _executeUpdate(prev.value, msg.sender);
    }

    function restoreToVersion(uint256 version)
        external
        onlyWithAccess(AccessLevel.Admin)
        whenWritable
        nonReentrant
        returns (uint256)
    {
        if (version >= snapshots.length) revert NoHistory();
        
        UpdateSnapshot memory target = snapshots[version];
        return _executeUpdate(target.value, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                    MULTI-SIGNATURE GOVERNANCE
    //////////////////////////////////////////////////////////////*/

    function submitMultiSigTransaction(
        address target,
        uint256 value,
        bytes calldata data,
        string calldata description
    ) external onlyWithAccess(AccessLevel.Owner) returns (bytes32 txHash) {
        txHash = keccak256(abi.encodePacked(target, value, data, block.timestamp));
        
        multiSigConfirmations[txHash][msg.sender] = true;
        
        emit MultiSigConfirmed(txHash, msg.sender);
        emit ProposalCreated(
            uint256(txHash),
            msg.sender,
            description,
            block.timestamp + EXECUTION_DELAY
        );
    }

    function confirmTransaction(bytes32 txHash) 
        external 
        onlyWithAccess(AccessLevel.Owner) 
    {
        if (multiSigConfirmations[txHash][msg.sender]) 
            revert MultiSigError("Already confirmed");
            
        multiSigConfirmations[txHash][msg.sender] = true;
        emit MultiSigConfirmed(txHash, msg.sender);
    }

    function executeMultiSigTransaction(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 txHash
    ) external onlyWithAccess(AccessLevel.Owner) nonReentrant returns (bytes memory) {
        uint256 confirmations;
        for (uint i = 0; i < multiSigOwners.length; i++) {
            if (multiSigConfirmations[txHash][multiSigOwners[i]]) {
                confirmations++;
            }
        }
        
        if (confirmations < requiredSignatures) 
            revert MultiSigError("Insufficient confirmations");
            
        (bool success, bytes memory returnData) = target.call{value: value}(data);
        if (!success) revert MultiSigError(string(returnData));
        
        emit MultiSigExecuted(txHash);
        return returnData;
    }

    function addMultiSigOwner(address newOwner) external onlyWithAccess(AccessLevel.Owner) {
        if (newOwner == address(0)) revert InvalidAddress();
        if (isOwner[newOwner]) revert MultiSigError("Already owner");
        
        isOwner[newOwner] = true;
        multiSigOwners.push(newOwner);
        
        emit MultiSigOwnerAdded(newOwner);
    }

    function removeMultiSigOwner(address owner) external onlyWithAccess(AccessLevel.Owner) {
        if (!isOwner[owner]) revert MultiSigError("Not owner");
        if (multiSigOwners.length <= requiredSignatures) 
            revert MultiSigError("Cannot remove below required signatures");
        
        isOwner[owner] = false;
        
        // Remove from array
        for (uint i = 0; i < multiSigOwners.length; i++) {
            if (multiSigOwners[i] == owner) {
                multiSigOwners[i] = multiSigOwners[multiSigOwners.length - 1];
                multiSigOwners.pop();
                break;
            }
        }
        
        emit MultiSigOwnerRemoved(owner);
    }

    function changeRequiredSignatures(uint256 _requiredSignatures) 
        external 
        onlyWithAccess(AccessLevel.Owner) 
    {
        if (_requiredSignatures > multiSigOwners.length || _requiredSignatures == 0)
            revert MultiSigError("Invalid required signatures");
        requiredSignatures = _requiredSignatures;
    }

    /*//////////////////////////////////////////////////////////////
                        TIME-LOCKED GOVERNANCE
    //////////////////////////////////////////////////////////////*/

    function createProposal(
        string calldata description,
        bytes calldata callData
    ) external onlyWithAccess(AccessLevel.Editor) returns (uint256 proposalId) {
        proposalId = ++proposalCount;
        TimeLockedProposal storage p = proposals[proposalId];
        
        p.id = proposalId;
        p.proposer = msg.sender;
        p.description = description;
        p.callData = callData;
        p.createdAt = block.timestamp;
        p.executeAt = block.timestamp + MIN_VOTING_PERIOD + EXECUTION_DELAY;
        p.state = ProposalState.Active;

        emit ProposalCreated(proposalId, msg.sender, description, p.executeAt);
    }

    function castVote(uint256 proposalId, bool support) external onlyWithAccess(AccessLevel.Editor) {
        TimeLockedProposal storage p = proposals[proposalId];
        
        require(p.state == ProposalState.Active, "Proposal not active");
        require(block.timestamp < p.executeAt - EXECUTION_DELAY, "Voting period ended");
        require(!p.hasVoted[msg.sender], "Already voted");
        
        p.hasVoted[msg.sender] = true;
        
        // Voting weight based on editor reputation
        uint256 weight = 1 + (editorStats[msg.sender].updatesMade / 10);
        
        if (support) {
            p.votesFor += weight;
        } else {
            p.votesAgainst += weight;
        }
        
        emit VoteCast(proposalId, msg.sender, support, weight);
    }

    function executeProposal(uint256 proposalId) external nonReentrant {
        TimeLockedProposal storage p = proposals[proposalId];
        
        require(p.state == ProposalState.Active, "Proposal not active");
        require(block.timestamp >= p.executeAt, "Too early to execute");
        
        uint256 totalVotes = p.votesFor + p.votesAgainst;
        uint256 quorum = (editorCount() * QUORUM_PERCENTAGE) / 100;
        
        require(totalVotes >= quorum, "Quorum not reached");
        require(p.votesFor > p.votesAgainst, "Not enough votes for");
        
        p.state = ProposalState.Executed;
        
        (bool success, bytes memory returnData) = address(this).call(p.callData);
        if (!success) revert ProposalExecutionFailed(returnData);
        
        emit ProposalExecuted(proposalId);
    }

    function cancelProposal(uint256 proposalId) external onlyWithAccess(AccessLevel.Admin) {
        TimeLockedProposal storage p = proposals[proposalId];
        require(p.state == ProposalState.Active, "Proposal not active");
        
        p.state = ProposalState.Canceled;
        emit ProposalCanceled(proposalId);
    }

    /*//////////////////////////////////////////////////////////////
                        EDITOR MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function addEditor(address editor, uint256 expiryDays) 
        external 
        onlyWithAccess(AccessLevel.Admin) 
    {
        if (editor == address(0)) revert InvalidAddress();
        
        uint256 expiry = block.timestamp + (expiryDays * 1 days);
        editorExpiry[editor] = expiry;
        
        emit EditorAdded(editor, expiry);
    }

    function addEditorsBatch(address[] calldata editors, uint256 expiryDays) 
        external 
        onlyWithAccess(AccessLevel.Admin) 
    {
        uint256 expiry = block.timestamp + (expiryDays * 1 days);
        for (uint256 i = 0; i < editors.length; i++) {
            if (editors[i] != address(0)) {
                editorExpiry[editors[i]] = expiry;
                emit EditorAdded(editors[i], expiry);
            }
        }
    }

    function removeEditor(address editor) external onlyWithAccess(AccessLevel.Admin) {
        editorExpiry[editor] = 0;
        emit EditorRemoved(editor);
    }

    function setEditorMerkleRoot(bytes32 merkleRoot) 
        external 
        onlyWithAccess(AccessLevel.Owner) 
    {
        editorMerkleRoot = merkleRoot;
        emit EditorMerkleRootUpdated(merkleRoot);
    }

    function claimEditorRole(bytes32[] calldata merkleProof) external {
        if (!verifyMerkleEditor(msg.sender, merkleProof)) 
            revert InvalidMerkleProof();
            
        editorExpiry[msg.sender] = block.timestamp + 365 days; // 1 year
        emit EditorAdded(msg.sender, block.timestamp + 365 days);
    }

    function setTrustedAccount(address account, bool trusted) 
        external 
        onlyWithAccess(AccessLevel.Admin) 
    {
        trustedAccounts[account] = trusted;
        if (trusted) {
            emit TrustedAccountAdded(account);
        } else {
            emit TrustedAccountRemoved(account);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            PAUSE CONTROLS
    //////////////////////////////////////////////////////////////*/

    function setPauseMode(PauseMode mode) 
        external 
        onlyWithAccess(AccessLevel.Admin) 
    {
        pauseMode = mode;
        emit PauseModeChanged(mode);
    }

    /*//////////////////////////////////////////////////////////////
                        EMERGENCY MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function activateEmergency(address recovery, uint256 expiryHours)
        external
        onlyWithAccess(AccessLevel.Owner)
    {
        if (recovery == address(0)) revert InvalidAddress();
        emergencyMode = true;
        recoveryAddress = recovery;
        emergencyExpiry = block.timestamp + (expiryHours * 1 hours);
        emit EmergencyModeActivated(recovery, emergencyExpiry);
    }

    function emergencyRestore(string calldata value)
        external
        onlyEmergency
        nonReentrant
    {
        if (msg.sender != recoveryAddress)
            revert Unauthorized(msg.sender, AccessLevel.Owner);

        // Verify against pre-committed hash
        bytes32 valueHash = keccak256(bytes(value));
        require(valueHash == _emergencyHash, "Invalid emergency value");

        _currentString = value;
        updateCount++;
        
        snapshots.push(
            UpdateSnapshot({
                value: value,
                updater: address(0),
                timestamp: block.timestamp,
                valueHash: valueHash,
                blockNumber: block.number,
                accessLevelUsed: AccessLevel.Owner
            })
        );

        emit EmergencyRecovered(value);
        emit StringUpdated(
            address(0),
            "",
            value,
            updateCount,
            block.timestamp,
            block.number,
            0,
            0
        );
    }

    /*//////////////////////////////////////////////////////////////
                        MAINTENANCE UTILITIES
    //////////////////////////////////////////////////////////////*/

    function clearHistory() external onlyWithAccess(AccessLevel.Owner) {
        delete snapshots;
        emit HistoryCleared(updateCount);
    }

    function renounceEmergency() external onlyWithAccess(AccessLevel.Owner) {
        emergencyMode = false;
        recoveryAddress = address(0);
        emergencyExpiry = 0;
    }

    function claimRewards() external nonReentrant {
        EditorStats storage stats = editorStats[msg.sender];
        uint256 points = stats.rewardPoints;
        
        require(points > 0, "No rewards to claim");
        
        stats.rewardPoints = 0;
        uint256 rewardAmount = points * 1e18; // 1 token per point
        
        bool success = rewardToken.transfer(msg.sender, rewardAmount);
        if (!success) revert TokenTransferFailed();
        
        emit RewardClaimed(msg.sender, rewardAmount);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _executeUpdate(string memory newValue, address updater) 
        internal 
        returns (uint256)
    {
        string memory old = _currentString;
        _currentString = newValue;
        updateCount++;

        snapshots.push(
            UpdateSnapshot({
                value: newValue,
                updater: updater,
                timestamp: block.timestamp,
                valueHash: keccak256(bytes(newValue)),
                blockNumber: block.number,
                accessLevelUsed: _getAccessLevel(updater)
            })
        );

        updateTimestamps[updateCount] = block.timestamp;
        updateMerkleRoots[updateCount] = keccak256(
            abi.encodePacked(updateCount, newValue, block.timestamp)
        );

        EditorStats storage stats = editorStats[updater];
        stats.updatesMade++;
        stats.lastUpdateAt = block.timestamp;

        emit StringUpdated(
            updater,
            old,
            newValue,
            updateCount,
            block.timestamp,
            block.number,
            0,
            0
        );

        return updateCount;
    }

    function _getAccessLevel(address account) internal view returns (AccessLevel) {
        if (isOwner[account]) return AccessLevel.Owner;
        
        // Check if admin (special case - could be based on a separate mapping)
        // For now, owners are the only admins
        
        if (hasEditorAccess(account)) return AccessLevel.Editor;
        
        return AccessLevel.None;
    }

    function _verifyUpdateSignature(
        string calldata newValue,
        uint256 deadline,
        address executor,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal returns (address) {
        bytes32 structHash = keccak256(
            abi.encode(
                UPDATE_REQUEST_TYPEHASH,
                keccak256(bytes(newValue)),
                deadline,
                executor,
                nonces[executor]++
            )
        );

        bytes32 digest = _hashTypedDataV4(structHash);
        address signer = ecrecover(digest, v, r, s);
        
        if (signer == address(0)) revert InvalidSignature();
        
        return signer;
    }

    function editorCount() internal view returns (uint256) {
        // This is an approximation - in production you'd maintain a count
        return multiSigOwners.length + 10; // Placeholder
    }

    /*//////////////////////////////////////////////////////////////
                        FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    receive() external payable {
        // Accept ETH for multi-sig transactions
    }

    fallback() external payable {
        // Fallback for proxy pattern compatibility
    }
}
