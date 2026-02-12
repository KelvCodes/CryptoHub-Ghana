// SPDX-License-Identifier: GNU
pragma solidity ^0.8.13;

/**
 * MyContract v4.0 — Enterprise & Audit-Grade Solidity Contract
 *
 * Author: Kelvin
 *
 * This contract demonstrates:
 * - Secure string storage
 * - Role-based access control
 * - Rate limiting
 * - Pausing & locking
 * - Historical tracking
 * - Integrity verification
 * - Emergency recovery patterns
 * - Governance-style admin approvals
 */
contract MyContract {
    // Versioning & Metadata
    string public constant CONTRACT_NAME = "MyContract";
    string public constant CONTRACT_VERSION = "4.0.0";

    // Constants
    uint256 public constant MIN_UPDATE_INTERVAL = 30;
    uint256 public constant MAX_LOCK_DURATION = 30 days;
    uint256 public constant EMERGENCY_COOLDOWN = 1 hours;

    // Storage Variables
    string private _attribute;
    bytes32 private _attributeHash;

    address public owner;
    mapping(address => bool) public admins;

    bool public paused;
    bool public emergencyMode;

    uint256 public lastUpdated;
    uint256 public lastUpdateAttempt;
    uint256 public lockUntil;
    uint256 public lastEmergencyAction;

    uint256 public totalUpdates;
    uint256 public totalAdminsAdded;

    // History Storage
    struct HistoryEntry {
        string value;
        bytes32 valueHash;
        uint256 timestamp;
        address updater;
        bool integrityVerified;
    }

    HistoryEntry[] private history;

    // Admin Proposals
    struct AdminProposal {
        address proposedAdmin;
        address proposer;
        uint256 timestamp;
        bool approved;
        bool executed;
    }

    AdminProposal[] private adminProposals;

    // Custom Errors
    error Unauthorized(address caller);
    error EmptyString();
    error ContractPaused();
    error AttributeLocked(uint256 until);
    error UpdateTooFrequent(uint256 nextAllowedTime);
    error InvalidAddress();
    error IntegrityMismatch();
    error EmergencyActive();
    error LockDurationTooLong();
    error CooldownActive(uint256 nextAllowedTime);

    // Events
    event AttributeUpdated(
        address indexed updater,
        string oldValue,
        string newValue,
        uint256 timestamp
    );

    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    event ContractPaused(address indexed by);
    event ContractUnpaused(address indexed by);
    event AttributeLockedEvent(uint256 until);
    event AttributeUnlockedEvent();
    event EmergencyModeEnabled(address indexed by);
    event EmergencyModeDisabled(address indexed by);
    event AdminProposalCreated(uint256 indexed id, address indexed admin);
    event AdminProposalApproved(uint256 indexed id);
    event AdminProposalExecuted(uint256 indexed id);

    // Modifiers
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized(msg.sender);
        _;
    }

    modifier onlyAdminOrOwner() {
        if (msg.sender != owner && !admins[msg.sender]) {
            revert Unauthorized(msg.sender);
        }
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier whenNotLocked() {
        if (block.timestamp < lockUntil) revert AttributeLocked(lockUntil);
        _;
    }

    modifier rateLimited() {
        if (block.timestamp < lastUpdateAttempt + MIN_UPDATE_INTERVAL) {
            revert UpdateTooFrequent(lastUpdateAttempt + MIN_UPDATE_INTERVAL);
        }
        _;
    }

    modifier noEmergency() {
        if (emergencyMode) revert EmergencyActive();
        _;
    }

    modifier emergencyCooldown() {
        if (block.timestamp < lastEmergencyAction + EMERGENCY_COOLDOWN) {
            revert CooldownActive(lastEmergencyAction + EMERGENCY_COOLDOWN);
        }
        _;
    }

    // Constructor
    constructor(string memory initialValue) {
        require(bytes(initialValue).length > 0, "Empty string");
        owner = msg.sender;
        _setAttribute(initialValue);
        _addHistoryEntry(initialValue, msg.sender);
    }

    // Internal Functions
    function _setAttribute(string memory newValue) internal {
        _attribute = newValue;
        _attributeHash = keccak256(abi.encodePacked(newValue));
        lastUpdated = block.timestamp;
        lastUpdateAttempt = block.timestamp;
        totalUpdates++;
    }

    function _verify(string memory value, bytes32 hash) internal pure returns (bool) {
        return keccak256(abi.encodePacked(value)) == hash;
    }

    function _addHistoryEntry(string memory value, address updater) internal {
        history.push(
            HistoryEntry({
                value: value,
                valueHash: _attributeHash,
                timestamp: block.timestamp,
                updater: updater,
                integrityVerified: true
            })
        );
    }

    // View Functions
    function getAttribute() external view returns (string memory) {
        return _attribute;
    }

    function getAttributeHash() external view returns (bytes32) {
        return _attributeHash;
    }

    function verifyIntegrity() external view returns (bool) {
        return _verify(_attribute, _attributeHash);
    }

    function getHistoryLength() external view returns (uint256) {
        return history.length;
    }

    function getHistory(uint256 offset, uint256 limit) external view returns (HistoryEntry[] memory) {
        uint256 end = offset + limit;
        if (end > history.length) {
            end = history.length;
        }

        HistoryEntry[] memory page = new HistoryEntry[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            page[i - offset] = history[i];
        }
        return page;
    }

    function getSystemStatus() external view returns (
        bool isPaused,
        bool isEmergency,
        uint256 updates,
        uint256 adminsCount,
        uint256 lastChange
    ) {
        return (paused, emergencyMode, totalUpdates, totalAdminsAdded, lastUpdated);
    }

    // Write Functions
    function setAttribute(string memory newValue) 
        external 
        onlyAdminOrOwner 
        whenNotPaused 
        whenNotLocked 
        noEmergency 
        rateLimited 
    {
        require(bytes(newValue).length > 0, "Empty string");
        
        string memory oldValue = _attribute;
        _setAttribute(newValue);
        _addHistoryEntry(newValue, msg.sender);
        
        emit AttributeUpdated(msg.sender, oldValue, newValue, block.timestamp);
    }

    // Pause & Lock Controls
    function pause() external onlyOwner {
        paused = true;
        emit ContractPaused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit ContractUnpaused(msg.sender);
    }

    function lockAttribute(uint256 duration) external onlyOwner {
        require(duration <= MAX_LOCK_DURATION, "Duration too long");
        lockUntil = block.timestamp + duration;
        emit AttributeLockedEvent(lockUntil);
    }

    function unlockAttribute() external onlyOwner {
        lockUntil = 0;
        emit AttributeUnlockedEvent();
    }

    function enableEmergencyMode() external onlyOwner emergencyCooldown {
        emergencyMode = true;
        lastEmergencyAction = block.timestamp;
        emit EmergencyModeEnabled(msg.sender);
    }

    function disableEmergencyMode() external onlyOwner emergencyCooldown {
        emergencyMode = false;
        lastEmergencyAction = block.timestamp;
        emit EmergencyModeDisabled(msg.sender);
    }

    // Admin Governance
    function proposeAdmin(address admin) external onlyAdminOrOwner {
        require(admin != address(0), "Invalid address");
        
        adminProposals.push(
            AdminProposal({
                proposedAdmin: admin,
                proposer: msg.sender,
                timestamp: block.timestamp,
                approved: false,
                executed: false
            })
        );
        
        emit AdminProposalCreated(adminProposals.length - 1, admin);
    }

    function approveAdminProposal(uint256 id) external onlyOwner {
        require(id < adminProposals.length, "Invalid proposal ID");
        AdminProposal storage proposal = adminProposals[id];
        require(!proposal.approved, "Already approved");
        require(!proposal.executed, "Already executed");
        
        proposal.approved = true;
        emit AdminProposalApproved(id);
    }

    function executeAdminProposal(uint256 id) external onlyOwner {
        require(id < adminProposals.length, "Invalid proposal ID");
        AdminProposal storage proposal = adminProposals[id];
        require(proposal.approved, "Not approved");
        require(!proposal.executed, "Already executed");
        
        admins[proposal.proposedAdmin] = true;
        totalAdminsAdded++;
        proposal.executed = true;
        
        emit AdminAdded(proposal.proposedAdmin);
        emit AdminProposalExecuted(id);
    }

    function removeAdmin(address admin) external onlyOwner {
        require(admin != address(0), "Invalid address");
        require(admins[admin], "Not an admin");
        
        admins[admin] = false;
        emit AdminRemoved(admin);
    }

    // Ownership
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    // Fallbacks
    receive() external payable {}
    fallback() external payable {}
}
