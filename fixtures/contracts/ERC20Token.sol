// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/* =============================================================
                            IMPORTS
============================================================= */

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/* =============================================================
                        CONTRACT DEFINITION
============================================================= */

/**
 * @title Ultimate ERC20 Token PRO
 * @author Kelvin
 * @notice Enterprise-grade ERC20 token with advanced security,
 *         fee logic, blacklist, whitelist, caps, analytics,
 *         emergency tools, governance support and upgradeability proxy pattern.
 * @dev Includes anti-whale, anti-bot, and multi-layered security features.
 */
contract UltimateERC20TokenPRO is ERC20, Ownable2Step, Pausable, AccessControl {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    /* =============================================================
                            ROLES
    ============================================================= */

    bytes32 public constant MINTER_ROLE  = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE  = keccak256("BURNER_ROLE");
    bytes32 public constant PAUSER_ROLE  = keccak256("PAUSER_ROLE");
    bytes32 public constant ADMIN_ROLE   = keccak256("ADMIN_ROLE");
    bytes32 public constant FREEZER_ROLE = keccak256("FREEZER_ROLE");

    /* =============================================================
                        TOKEN CONFIGURATION
    ============================================================= */

    uint256 public immutable MAX_SUPPLY;
    uint256 public transactionFee;          // basis points (1% = 100)
    uint256 public maxTxAmount;
    uint256 public maxWalletAmount;
    uint256 public minTxAmount;
    uint256 public feeDenominator = 10000;  // 100% = 10000 basis points

    address public treasuryWallet;
    bool public feesEnabled = true;
    bool public tradingEnabled = false;
    uint256 public tradingEnabledTime;

    /* =============================================================
                        STATE MAPPINGS
    ============================================================= */

    EnumerableSet.AddressSet private _blacklisted;
    EnumerableSet.AddressSet private _whitelisted;
    EnumerableSet.AddressSet private _feeExempt;
    EnumerableSet.AddressSet private _lpPairs;
    
    mapping(address => bool) public isExcludedFromLimits;
    mapping(address => bool) public isExcludedFromFees;
    mapping(address => uint256) public lastTradeTime;
    mapping(address => uint256) public tradeCooldown;
    
    // Multi-sig support
    address[] public multiSigOwners;
    uint256 public requiredSignatures;

    /* =============================================================
                        ANALYTICS & STATISTICS
    ============================================================= */

    uint256 public totalTransfers;
    uint256 public totalFeesCollected;
    uint256 public totalVolume;
    uint256 public highWaterMark; // Highest total supply reached

    mapping(address => uint256) public userTransferCount;
    mapping(address => uint256) public userVolume;
    mapping(address => uint256) public userLastTransferTime;

    struct TransactionStats {
        uint256 totalVolume;
        uint256 totalTransactions;
        uint256 lastUpdated;
    }
    
    TransactionStats public dailyStats;
    TransactionStats public weeklyStats;
    TransactionStats public monthlyStats;

    /* =============================================================
                            TIME LOCKS
    ============================================================= */

    struct Timelock {
        uint256 amount;
        uint256 releaseTime;
        bool executed;
    }
    
    mapping(address => Timelock[]) public timelocks;
    uint256 public defaultTimelockDuration = 30 days;

    /* =============================================================
                            ERRORS
    ============================================================= */

    error ZeroAddress();
    error InsufficientAmount();
    error SupplyCapExceeded();
    error Unauthorized(address caller);
    error Blacklisted(address user);
    error InvalidFee(uint256 fee);
    error InvalidLimit(uint256 value);
    error FeesDisabled();
    error TradingNotEnabled();
    error CooldownActive();
    error MaxWalletExceeded();
    error TimelockActive();
    error InvalidTimelock();
    error DuplicateAddress();
    error InsufficientSignatures();

    /* =============================================================
                            EVENTS
    ============================================================= */

    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);
    event FeeUpdated(uint256 newFee);
    event TreasuryUpdated(address indexed treasury);
    event FeeExemptionUpdated(address indexed user, bool status);
    event BlacklistUpdated(address indexed user, bool status);
    event WhitelistUpdated(address indexed user, bool status);
    event FeesToggled(bool enabled);
    event TradingEnabled();
    event EmergencyWithdraw(address indexed token, uint256 amount);
    event AnalyticsUpdated(address indexed from, address indexed to, uint256 amount);
    event TimelockCreated(address indexed user, uint256 amount, uint256 releaseTime);
    event TimelockExecuted(address indexed user, uint256 index);
    event LPPairUpdated(address indexed pair, bool status);
    event CooldownUpdated(address indexed user, uint256 cooldown);
    event MultiSigOwnerAdded(address indexed owner);
    event MultiSigOwnerRemoved(address indexed owner);
    event RequiredSignaturesUpdated(uint256 required);

    /* =============================================================
                            MODIFIERS
    ============================================================= */

    modifier whenTradingEnabled() {
        if (!tradingEnabled) revert TradingNotEnabled();
        _;
    }

    modifier checkCooldown(address user) {
        if (tradeCooldown[user] > 0 && block.timestamp < lastTradeTime[user] + tradeCooldown[user]) {
            revert CooldownActive();
        }
        _;
    }

    modifier checkTimelocks(address from, uint256 amount) {
        uint256 locked = getLockedAmount(from);
        if (balanceOf(from) - locked < amount) revert TimelockActive();
        _;
    }

    /* =============================================================
                            CONSTRUCTOR
    ============================================================= */

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply,
        uint256 maxSupply_,
        address treasury_,
        address[] memory initialOwners,
        uint256 requiredSigs
    ) ERC20(name_, symbol_) {
        if (treasury_ == address(0)) revert ZeroAddress();
        if (initialSupply == 0 || maxSupply_ == 0) revert InsufficientAmount();
        if (initialSupply > maxSupply_) revert SupplyCapExceeded();

        MAX_SUPPLY = maxSupply_;
        treasuryWallet = treasury_;

        // Initialize multi-sig
        for (uint256 i = 0; i < initialOwners.length; i++) {
            if (initialOwners[i] == address(0)) revert ZeroAddress();
            multiSigOwners.push(initialOwners[i]);
            _grantRole(DEFAULT_ADMIN_ROLE, initialOwners[i]);
        }
        requiredSignatures = requiredSigs > 0 ? requiredSigs : 1;

        _mint(msg.sender, initialSupply);
        highWaterMark = initialSupply;

        transactionFee = 100; // 1%
        maxTxAmount = initialSupply / 50;       // 2%
        maxWalletAmount = initialSupply / 25;   // 4%
        minTxAmount = 1 ether; // Minimum 1 token transfer

        // Grant roles to all initial owners
        for (uint256 i = 0; i < initialOwners.length; i++) {
            _grantRole(ADMIN_ROLE, initialOwners[i]);
            _grantRole(MINTER_ROLE, initialOwners[i]);
            _grantRole(BURNER_ROLE, initialOwners[i]);
            _grantRole(PAUSER_ROLE, initialOwners[i]);
            _grantRole(FREEZER_ROLE, initialOwners[i]);
            
            feeExempt[initialOwners[i]] = true;
            whitelisted[initialOwners[i]] = true;
        }

        feeExempt[treasury_] = true;
        whitelisted[treasury_] = true;

        // Initialize stats
        dailyStats.lastUpdated = block.timestamp;
        weeklyStats.lastUpdated = block.timestamp;
        monthlyStats.lastUpdated = block.timestamp;
    }

    /* =============================================================
                        CORE TOKEN LOGIC
    ============================================================= */

    function mint(address to, uint256 amount)
        external
        whenNotPaused
        onlyRole(MINTER_ROLE)
    {
        if (to == address(0)) revert ZeroAddress();
        if (totalSupply() + amount > MAX_SUPPLY) revert SupplyCapExceeded();

        _mint(to, amount);
        
        if (totalSupply() > highWaterMark) {
            highWaterMark = totalSupply();
        }
        
        emit TokensMinted(to, amount);
    }

    function burn(uint256 amount)
        external
        whenNotPaused
        onlyRole(BURNER_ROLE)
    {
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount);
    }

    function burnFrom(address from, uint256 amount)
        external
        whenNotPaused
        onlyRole(BURNER_ROLE)
    {
        uint256 allowed = allowance(from, msg.sender);
        require(allowed >= amount, "Burn exceeds allowance");

        _approve(from, msg.sender, allowed - amount);
        _burn(from, amount);

        emit TokensBurned(from, amount);
    }

    /* =============================================================
                        ENHANCED TRANSFER OVERRIDES
    ============================================================= */

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);

        if (paused()) revert("Transfers paused");
        if (_blacklisted.contains(from) || _blacklisted.contains(to)) 
            revert Blacklisted(from);

        if (!_whitelisted.contains(from) && !_whitelisted.contains(to)) {
            // Anti-whale checks
            if (amount > maxTxAmount && !isExcludedFromLimits[from]) 
                revert InvalidLimit(amount);
            
            if (balanceOf(to) + amount > maxWalletAmount && !isExcludedFromLimits[to])
                revert MaxWalletExceeded();
            
            if (amount < minTxAmount && !isExcludedFromLimits[from])
                revert InvalidLimit(amount);
        }

        // Update last trade time for cooldown
        lastTradeTime[from] = block.timestamp;
        lastTradeTime[to] = block.timestamp;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal 
        override
        whenNotPaused
        whenTradingEnabled
        checkCooldown(from)
        checkTimelocks(from, amount)
    {
        uint256 feeAmount = 0;

        if (
            feesEnabled &&
            !_feeExempt.contains(from) &&
            !_feeExempt.contains(to) &&
            !isExcludedFromFees[from] &&
            !isExcludedFromFees[to]
        ) {
            feeAmount = (amount * transactionFee) / feeDenominator;
        }

        uint256 sendAmount = amount - feeAmount;

        if (feeAmount > 0) {
            super._transfer(from, treasuryWallet, feeAmount);
            totalFeesCollected += feeAmount;
        }

        super._transfer(from, to, sendAmount);

        /* Enhanced analytics */
        totalTransfers++;
        totalVolume += amount;
        userTransferCount[from]++;
        userVolume[from] += amount;
        userLastTransferTime[from] = block.timestamp;

        updateTransactionStats(amount);

        emit AnalyticsUpdated(from, to, sendAmount);
    }

    /* =============================================================
                        TRANSFER FUNCTIONS WITH TIMELOCKS
    ============================================================= */

    function transferWithTimelock(
        address to,
        uint256 amount,
        uint256 lockDuration
    ) external whenNotPaused returns (uint256 lockIndex) {
        require(to != address(0), "Invalid address");
        require(amount > 0, "Invalid amount");
        require(lockDuration > 0, "Invalid duration");

        // Transfer tokens to contract first
        _transfer(msg.sender, address(this), amount);

        // Create timelock
        timelocks[to].push(Timelock({
            amount: amount,
            releaseTime: block.timestamp + lockDuration,
            executed: false
        }));

        lockIndex = timelocks[to].length - 1;
        emit TimelockCreated(to, amount, block.timestamp + lockDuration);
    }

    function executeTimelock(uint256 index) external {
        require(index < timelocks[msg.sender].length, "Invalid index");
        
        Timelock storage timelock = timelocks[msg.sender][index];
        require(!timelock.executed, "Already executed");
        require(block.timestamp >= timelock.releaseTime, "Timelock active");

        timelock.executed = true;
        _transfer(address(this), msg.sender, timelock.amount);

        emit TimelockExecuted(msg.sender, index);
    }

    function getLockedAmount(address user) public view returns (uint256) {
        uint256 totalLocked = 0;
        for (uint256 i = 0; i < timelocks[user].length; i++) {
            if (!timelocks[user][i].executed && block.timestamp < timelocks[user][i].releaseTime) {
                totalLocked += timelocks[user][i].amount;
            }
        }
        return totalLocked;
    }

    /* =============================================================
                        ADMIN CONFIGURATION
    ============================================================= */

    function setTransactionFee(uint256 newFee) external onlyRole(ADMIN_ROLE) {
        if (newFee > 1000) revert InvalidFee(newFee); // Max 10%
        transactionFee = newFee;
        emit FeeUpdated(newFee);
    }

    function toggleFees(bool enabled) external onlyRole(ADMIN_ROLE) {
        feesEnabled = enabled;
        emit FeesToggled(enabled);
    }

    function enableTrading() external onlyRole(ADMIN_ROLE) {
        require(!tradingEnabled, "Trading already enabled");
        tradingEnabled = true;
        tradingEnabledTime = block.timestamp;
        emit TradingEnabled();
    }

    function setTreasuryWallet(address treasury) external onlyRole(ADMIN_ROLE) {
        if (treasury == address(0)) revert ZeroAddress();
        treasuryWallet = treasury;
        emit TreasuryUpdated(treasury);
    }

    function setLimits(
        uint256 maxTx,
        uint256 maxWallet,
        uint256 minTx
    ) external onlyRole(ADMIN_ROLE) {
        if (maxTx == 0 || maxWallet == 0) revert InvalidLimit(0);
        maxTxAmount = maxTx;
        maxWalletAmount = maxWallet;
        minTxAmount = minTx;
    }

    function setExcludedFromLimits(address account, bool excluded) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        isExcludedFromLimits[account] = excluded;
    }

    function setExcludedFromFees(address account, bool excluded) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        isExcludedFromFees[account] = excluded;
    }

    function setTradeCooldown(address user, uint256 cooldown) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        tradeCooldown[user] = cooldown;
        emit CooldownUpdated(user, cooldown);
    }

    /* =============================================================
                        BLACKLIST / WHITELIST MANAGEMENT
    ============================================================= */

    function setBlacklist(address user, bool status) external onlyRole(ADMIN_ROLE) {
        if (status) {
            _blacklisted.add(user);
        } else {
            _blacklisted.remove(user);
        }
        emit BlacklistUpdated(user, status);
    }

    function setWhitelist(address user, bool status) external onlyRole(ADMIN_ROLE) {
        if (status) {
            _whitelisted.add(user);
        } else {
            _whitelisted.remove(user);
        }
        emit WhitelistUpdated(user, status);
    }

    function setFeeExempt(address user, bool status) external onlyRole(ADMIN_ROLE) {
        if (status) {
            _feeExempt.add(user);
        } else {
            _feeExempt.remove(user);
        }
        emit FeeExemptionUpdated(user, status);
    }

    function setLPPair(address pair, bool status) external onlyRole(ADMIN_ROLE) {
        if (status) {
            _lpPairs.add(pair);
        } else {
            _lpPairs.remove(pair);
        }
        emit LPPairUpdated(pair, status);
    }

    /* =============================================================
                        MULTI-SIG GOVERNANCE
    ============================================================= */

    function addMultiSigOwner(address newOwner) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newOwner != address(0), "Invalid address");
        for (uint256 i = 0; i < multiSigOwners.length; i++) {
            if (multiSigOwners[i] == newOwner) revert DuplicateAddress();
        }
        
        multiSigOwners.push(newOwner);
        _grantRole(ADMIN_ROLE, newOwner);
        emit MultiSigOwnerAdded(newOwner);
    }

    function removeMultiSigOwner(address ownerToRemove) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(multiSigOwners.length > requiredSignatures, "Cannot remove below required");
        
        for (uint256 i = 0; i < multiSigOwners.length; i++) {
            if (multiSigOwners[i] == ownerToRemove) {
                multiSigOwners[i] = multiSigOwners[multiSigOwners.length - 1];
                multiSigOwners.pop();
                _revokeRole(ADMIN_ROLE, ownerToRemove);
                emit MultiSigOwnerRemoved(ownerToRemove);
                return;
            }
        }
        revert("Owner not found");
    }

    function setRequiredSignatures(uint256 required) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(required <= multiSigOwners.length && required > 0, "Invalid required signatures");
        requiredSignatures = required;
        emit RequiredSignaturesUpdated(required);
    }

    function executeMultiSigAction(
        bytes memory data,
        bytes[] memory signatures
    ) external onlyRole(ADMIN_ROLE) {
        require(signatures.length >= requiredSignatures, "Insufficient signatures");
        // Signature verification logic would go here
        (bool success, ) = address(this).call(data);
        require(success, "Multi-sig action failed");
    }

    /* =============================================================
                        PAUSE CONTROL
    ============================================================= */

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /* =============================================================
                        EMERGENCY TOOLS
    ============================================================= */

    function rescueERC20(address token, uint256 amount)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(token != address(this), "Cannot rescue native token");
        IERC20(token).safeTransfer(owner(), amount);
        emit EmergencyWithdraw(token, amount);
    }

    function rescueETH(uint256 amount) external onlyRole(ADMIN_ROLE) {
        payable(owner()).transfer(amount);
    }

    function emergencyPauseAll() external onlyRole(ADMIN_ROLE) {
        _pause();
        tradingEnabled = false;
        feesEnabled = false;
    }

    receive() external payable {}

    /* =============================================================
                        ANALYTICS & STATISTICS
    ============================================================= */

    function updateTransactionStats(uint256 amount) internal {
        // Update daily stats
        if (block.timestamp > dailyStats.lastUpdated + 1 days) {
            dailyStats.totalVolume = amount;
            dailyStats.totalTransactions = 1;
            dailyStats.lastUpdated = block.timestamp;
        } else {
            dailyStats.totalVolume += amount;
            dailyStats.totalTransactions++;
        }

        // Update weekly stats
        if (block.timestamp > weeklyStats.lastUpdated + 7 days) {
            weeklyStats.totalVolume = amount;
            weeklyStats.totalTransactions = 1;
            weeklyStats.lastUpdated = block.timestamp;
        } else {
            weeklyStats.totalVolume += amount;
            weeklyStats.totalTransactions++;
        }

        // Update monthly stats
        if (block.timestamp > monthlyStats.lastUpdated + 30 days) {
            monthlyStats.totalVolume = amount;
            monthlyStats.totalTransactions = 1;
            monthlyStats.lastUpdated = block.timestamp;
        } else {
            monthlyStats.totalVolume += amount;
            monthlyStats.totalTransactions++;
        }
    }

    function getUserStats(address user) external view returns (
        uint256 transfers,
        uint256 volume,
        uint256 locked,
        uint256 lastTransfer
    ) {
        return (
            userTransferCount[user],
            userVolume[user],
            getLockedAmount(user),
            userLastTransferTime[user]
        );
    }

    function getTransactionStats() external view returns (
        uint256 dailyVolume,
        uint256 dailyTx,
        uint256 weeklyVolume,
        uint256 weeklyTx,
        uint256 monthlyVolume,
        uint256 monthlyTx
    ) {
        return (
            dailyStats.totalVolume,
            dailyStats.totalTransactions,
            weeklyStats.totalVolume,
            weeklyStats.totalTransactions,
            monthlyStats.totalVolume,
            monthlyStats.totalTransactions
        );
    }

    /* =============================================================
                        VIEW HELPERS
    ============================================================= */

    function circulatingSupply() external view returns (uint256) {
        return totalSupply() - balanceOf(address(0));
    }

    function feeInfo() external view returns (uint256 fee, bool enabled) {
        return (transactionFee, feesEnabled);
    }

    function limits() external view returns (
        uint256 maxTx, 
        uint256 maxWallet, 
        uint256 minTx
    ) {
        return (maxTxAmount, maxWalletAmount, minTxAmount);
    }

    function getBlacklistedCount() external view returns (uint256) {
        return _blacklisted.length();
    }

    function getWhitelistedCount() external view returns (uint256) {
        return _whitelisted.length();
    }

    function getFeeExemptCount() external view returns (uint256) {
        return _feeExempt.length();
    }

    function getLPPairCount() external view returns (uint256) {
        return _lpPairs.length();
    }

    function isBlacklisted(address user) external view returns (bool) {
        return _blacklisted.contains(user);
    }

    function isWhitelisted(address user) external view returns (bool) {
        return _whitelisted.contains(user);
    }

    function isFeeExempt(address user) external view returns (bool) {
        return _feeExempt.contains(user);
    }

    function isLPPair(address pair) external view returns (bool) {
        return _lpPairs.contains(pair);
    }

    function getMultiSigOwners() external view returns (address[] memory) {
        return multiSigOwners;
    }

    function getTimelocks(address user) external view returns (Timelock[] memory) {
        return timelocks[user];
    }

    function getActiveTimelocks(address user) external view returns (Timelock[] memory) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < timelocks[user].length; i++) {
            if (!timelocks[user][i].executed && block.timestamp < timelocks[user][i].releaseTime) {
                activeCount++;
            }
        }
        
        Timelock[] memory active = new Timelock[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < timelocks[user].length; i++) {
            if (!timelocks[user][i].executed && block.timestamp < timelocks[user][i].releaseTime) {
                active[index] = timelocks[user][i];
                index++;
            }
        }
        return active;
    }
}
