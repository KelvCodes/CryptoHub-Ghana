// SPDX-License-Identifier: GNU
pragma solidity ^0.8.19;

/**
 * @title UltraAdvancedErrorsContract
 * @author Kelvin
 * @notice Master-level Solidity example featuring advanced security, gas optimization,
 *         and complex DeFi-like mechanics. Production-ready with extensive testing patterns.
 * @dev Perfect for learning secure, production-grade contract architecture with advanced patterns.
 */

// Import OpenZeppelin contracts for enhanced security
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract UltraAdvancedErrorsContract is ReentrancyGuard, Pausable, AccessControl {
    using Math for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    // ============================================================
    // ======================= CONSTANTS ==========================
    // ============================================================

    string public constant CONTRACT_NAME = "UltraAdvancedErrorsContract";
    string public constant CONTRACT_VERSION = "4.0";
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    uint256 public constant MAX_FEE_BASIS_POINTS = 1000; // 10%
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;
    uint256 public constant MIN_DEPOSIT = 0.01 ether;
    uint256 public constant MAX_LOCK_PERIOD = 365 days;
    uint256 public constant WITHDRAWAL_COOLDOWN = 1 days;

    // ============================================================
    // ======================= STATE ==============================
    // ============================================================

    address payable public treasury;
    
    /// @notice Tier-based fee structure
    uint256 public baseFeeBasisPoints = 50; // 0.5%
    uint256 public vipFeeBasisPoints = 25;   // 0.25%
    uint256 public whaleThreshold = 10 ether;
    
    /// @notice User tracking with EnumerableSet for gas efficiency
    EnumerableSet.AddressSet private _users;
    
    /// @notice Structured user data
    struct UserInfo {
        uint256 totalDeposited;
        uint256 totalWithdrawn;
        uint256 lastDepositTime;
        uint256 lastWithdrawalTime;
        uint256 lockUntil;
        uint256 depositCount;
        uint256 withdrawalCount;
        bool isVIP;
        uint256 referralCount;
        address referrer;
    }
    
    mapping(address => UserInfo) public userInfo;
    mapping(address => uint256[]) public depositAmounts;
    mapping(address => uint256[]) public depositTimestamps;
    mapping(address => uint256[]) public withdrawalAmounts;
    mapping(address => uint256[]) public withdrawalTimestamps;
    
    /// @notice Referral system
    mapping(address => address[]) public referrals;
    mapping(address => uint256) public referralEarnings;
    
    /// @notice VIP status tracking
    uint256 public vipCount;
    
    /// @notice Global statistics
    uint256 public totalDeposited;
    uint256 public totalWithdrawn;
    uint256 public totalFeesCollected;
    uint256 public totalReferralRewards;
    uint256 public activeUsersCount;
    
    /// @notice Time-weighted average balance tracking
    mapping(address => uint256) public lastBalanceUpdate;
    mapping(address => uint256) public cumulativeBalance;
    mapping(address => uint256) public timeWeightedAverageBalance;
    
    /// @notice Withdrawal requests for 2-step withdrawals
    struct WithdrawalRequest {
        uint256 amount;
        uint256 requestedAt;
        bool processed;
    }
    mapping(address => WithdrawalRequest) public withdrawalRequests;

    // ============================================================
    // ======================= ERRORS =============================
    // ============================================================

    error Unauthorized(address caller, bytes32 requiredRole);
    error InvalidAmount(uint256 provided, uint256 minimum);
    error InsufficientBalance(uint256 requested, uint256 available);
    error TransferFailed(uint256 amount, address to, string reason);
    error ContractPaused(string operation);
    error InvalidLockPeriod(uint256 requested, uint256 max);
    error WithdrawalCooldown(uint256 remainingTime);
    error UserNotFound(address user);
    error ReferralCycleDetected(address referrer, address referee);
    error VIPStatusNotAchieved(uint256 requiredDeposit);
    error RequestExpired(uint256 requestedAt, uint256 expiryTime);
    error ArrayLengthMismatch(uint256 length1, uint256 length2);
    error ZeroAddressNotAllowed();
    error MathOverflow();

    // ============================================================
    // ======================= EVENTS =============================
    // ============================================================

    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event FeesUpdated(uint256 baseFee, uint256 vipFee, uint256 whaleThreshold);
    event Deposited(
        address indexed user, 
        uint256 amount, 
        uint256 fee, 
        uint256 netAmount,
        uint256 timestamp,
        address indexed referrer
    );
    event Withdrawn(
        address indexed user, 
        uint256 amount, 
        uint256 fee, 
        uint256 netAmount,
        uint256 timestamp
    );
    event WithdrawalRequested(address indexed user, uint256 amount, uint256 expiry);
    event WithdrawalExecuted(address indexed user, uint256 amount, uint256 fee);
    event VIPStatusUpdated(address indexed user, bool isVIP, uint256 timestamp);
    event ReferralReward(address indexed referrer, address indexed referee, uint256 amount);
    event BatchProcessed(uint256 userCount, uint256 totalAmount);
    event EmergencyWithdrawal(address indexed executor, uint256 amount, string reason);

    // ============================================================
    // ====================== CONSTRUCTOR =========================
    // ============================================================

    constructor(address payable _treasury) {
        if (_treasury == address(0)) revert ZeroAddressNotAllowed();
        
        treasury = _treasury;
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(TREASURER_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
        
        emit TreasuryUpdated(address(0), _treasury);
    }

    // ============================================================
    // =================== DEPOSITING LOGIC =======================
    // ============================================================

    /**
     * @notice Deposit ETH with advanced features
     * @param lockSeconds Optional lock period (0 for no lock)
     * @param referrer Address that referred this user (optional)
     */
    function deposit(
        uint256 lockSeconds,
        address referrer
    ) external payable whenNotPaused nonReentrant {
        if (msg.value < MIN_DEPOSIT) revert InvalidAmount(msg.value, MIN_DEPOSIT);
        if (lockSeconds > MAX_LOCK_PERIOD) revert InvalidLockPeriod(lockSeconds, MAX_LOCK_PERIOD);
        
        // Check for referral cycle
        if (referrer != address(0) && referrer != msg.sender) {
            _validateReferral(msg.sender, referrer);
        }
        
        // Calculate fees based on VIP status
        (uint256 fee, bool isVIP) = _calculateFee(msg.sender, msg.value);
        uint256 netAmount = msg.value - fee;
        
        // Update user info
        UserInfo storage user = userInfo[msg.sender];
        
        // First time user
        if (user.totalDeposited == 0) {
            _users.add(msg.sender);
            user.referrer = referrer;
        }
        
        // Update VIP status if threshold crossed
        bool newVIPStatus = user.totalDeposited + netAmount >= whaleThreshold;
        if (newVIPStatus != user.isVIP) {
            _updateVIPStatus(msg.sender, newVIPStatus);
        }
        
        // Update time-weighted average balance
        _updateTWAB(msg.sender);
        
        // Update user data
        user.totalDeposited += netAmount;
        user.lastDepositTime = block.timestamp;
        user.depositCount++;
        
        if (lockSeconds > 0) {
            user.lockUntil = block.timestamp + lockSeconds;
        }
        
        // Store deposit history
        depositAmounts[msg.sender].push(netAmount);
        depositTimestamps[msg.sender].push(block.timestamp);
        
        // Update global stats
        totalDeposited += netAmount;
        totalFeesCollected += fee;
        
        // Process referral if applicable
        if (user.referrer != address(0) && user.referrer != msg.sender) {
            _processReferralReward(user.referrer, fee);
        }
        
        emit Deposited(msg.sender, msg.value, fee, netAmount, block.timestamp, user.referrer);
    }

    // ============================================================
    // =================== WITHDRAWAL LOGIC =======================
    // ============================================================

    /**
     * @notice Request withdrawal (2-step process for security)
     */
    function requestWithdrawal(uint256 amount) external whenNotPaused nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        
        if (amount == 0) revert InvalidAmount(amount, 1);
        if (amount > user.totalDeposited) revert InsufficientBalance(amount, user.totalDeposited);
        if (block.timestamp < user.lockUntil) {
            revert WithdrawalCooldown(user.lockUntil - block.timestamp);
        }
        
        // Check cooldown period between withdrawals
        if (block.timestamp < user.lastWithdrawalTime + WITHDRAWAL_COOLDOWN) {
            revert WithdrawalCooldown((user.lastWithdrawalTime + WITHDRAWAL_COOLDOWN) - block.timestamp);
        }
        
        // Create withdrawal request (expires in 24 hours)
        withdrawalRequests[msg.sender] = WithdrawalRequest({
            amount: amount,
            requestedAt: block.timestamp,
            processed: false
        });
        
        emit WithdrawalRequested(msg.sender, amount, block.timestamp + 1 days);
    }

    /**
     * @notice Execute requested withdrawal
     */
    function executeWithdrawal() external whenNotPaused nonReentrant {
        WithdrawalRequest storage request = withdrawalRequests[msg.sender];
        UserInfo storage user = userInfo[msg.sender];
        
        if (request.amount == 0) revert InvalidAmount(0, 1);
        if (request.processed) revert CustomError("Request already processed");
        if (block.timestamp > request.requestedAt + 1 days) {
            revert RequestExpired(request.requestedAt, request.requestedAt + 1 days);
        }
        
        // Calculate fee
        (uint256 fee, ) = _calculateFee(msg.sender, request.amount);
        uint256 payout = request.amount - fee;
        
        // Update user data
        user.totalWithdrawn += payout;
        user.lastWithdrawalTime = block.timestamp;
        user.withdrawalCount++;
        request.processed = true;
        
        // Update time-weighted average balance
        _updateTWAB(msg.sender);
        
        // Store withdrawal history
        withdrawalAmounts[msg.sender].push(payout);
        withdrawalTimestamps[msg.sender].push(block.timestamp);
        
        // Update global stats
        totalWithdrawn += payout;
        totalFeesCollected += fee;
        
        // Transfer funds
        (bool success, bytes memory data) = payable(msg.sender).call{value: payout}("");
        if (!success) {
            string memory reason = _getRevertMessage(data);
            revert TransferFailed(payout, msg.sender, reason);
        }
        
        emit Withdrawn(msg.sender, request.amount, fee, payout, block.timestamp);
        emit WithdrawalExecuted(msg.sender, payout, fee);
    }

    // ============================================================
    // =================== ADMIN FUNCTIONS ========================
    // ============================================================

    /**
     * @notice Batch update fees for multiple users
     */
    function batchUpdateVIPStatus(address[] calldata users) external onlyRole(ADMIN_ROLE) {
        uint256 length = users.length;
        for (uint256 i = 0; i < length; i++) {
            address user = users[i];
            UserInfo storage userData = userInfo[user];
            bool newVIPStatus = userData.totalDeposited >= whaleThreshold;
            
            if (newVIPStatus != userData.isVIP) {
                _updateVIPStatus(user, newVIPStatus);
            }
        }
        
        emit BatchProcessed(length, 0);
    }

    /**
     * @notice Emergency withdrawal with reason (only in emergency)
     */
    function emergencyWithdraw(uint256 amount, string calldata reason) 
        external 
        onlyRole(EMERGENCY_ROLE) 
        whenPaused 
        nonReentrant 
    {
        uint256 balance = address(this).balance;
        if (amount > balance) revert InsufficientBalance(amount, balance);
        
        (bool success, ) = treasury.call{value: amount}("");
        if (!success) revert TransferFailed(amount, treasury, "Emergency withdrawal failed");
        
        emit EmergencyWithdrawal(msg.sender, amount, reason);
    }

    /**
     * @notice Update treasury address
     */
    function updateTreasury(address payable newTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newTreasury == address(0)) revert ZeroAddressNotAllowed();
        emit TreasuryUpdated(treasury, newTreasury);
        treasury = newTreasury;
    }

    /**
     * @notice Update fee structure
     */
    function updateFees(
        uint256 _baseFee,
        uint256 _vipFee,
        uint256 _whaleThreshold
    ) external onlyRole(ADMIN_ROLE) {
        if (_baseFee > MAX_FEE_BASIS_POINTS) revert InvalidAmount(_baseFee, MAX_FEE_BASIS_POINTS);
        if (_vipFee > _baseFee) revert InvalidAmount(_vipFee, _baseFee);
        
        emit FeesUpdated(baseFeeBasisPoints, _vipFee, whaleThreshold);
        
        baseFeeBasisPoints = _baseFee;
        vipFeeBasisPoints = _vipFee;
        whaleThreshold = _whaleThreshold;
    }

    // ============================================================
    // =================== INTERNAL FUNCTIONS =====================
    // ============================================================

    /**
     * @notice Calculate fee based on user's VIP status
     */
    function _calculateFee(address user, uint256 amount) internal view returns (uint256 fee, bool isVIP) {
        UserInfo storage userData = userInfo[user];
        isVIP = userData.isVIP || (userData.totalDeposited + amount >= whaleThreshold);
        uint256 feeRate = isVIP ? vipFeeBasisPoints : baseFeeBasisPoints;
        fee = amount.mulDiv(feeRate, BASIS_POINTS_DIVISOR, Math.Rounding.Floor);
    }

    /**
     * @notice Update VIP status
     */
    function _updateVIPStatus(address user, bool isVIP) internal {
        if (userInfo[user].isVIP != isVIP) {
            userInfo[user].isVIP = isVIP;
            if (isVIP) {
                vipCount++;
            } else {
                vipCount--;
            }
            emit VIPStatusUpdated(user, isVIP, block.timestamp);
        }
    }

    /**
     * @notice Update time-weighted average balance
     */
    function _updateTWAB(address user) internal {
        uint256 currentBalance = userInfo[user].totalDeposited;
        uint256 timeDelta = block.timestamp - lastBalanceUpdate[user];
        
        if (timeDelta > 0) {
            cumulativeBalance[user] += currentBalance * timeDelta;
            timeWeightedAverageBalance[user] = cumulativeBalance[user] / block.timestamp;
        }
        
        lastBalanceUpdate[user] = block.timestamp;
    }

    /**
     * @notice Process referral reward
     */
    function _processReferralReward(address referrer, uint256 fee) internal {
        uint256 reward = fee.mulDiv(2000, BASIS_POINTS_DIVISOR); // 20% of fee
        referralEarnings[referrer] += reward;
        userInfo[referrer].referralCount++;
        referrals[referrer].push(msg.sender);
        totalReferralRewards += reward;
        
        emit ReferralReward(referrer, msg.sender, reward);
    }

    /**
     * @notice Validate referral to prevent cycles
     */
    function _validateReferral(address user, address referrer) internal view {
        if (user == referrer) revert ReferralCycleDetected(referrer, user);
        
        // Check for cycles (max depth 5)
        address current = referrer;
        for (uint256 i = 0; i < 5; i++) {
            if (current == address(0)) break;
            if (current == user) revert ReferralCycleDetected(referrer, user);
            current = userInfo[current].referrer;
        }
    }

    /**
     * @notice Get revert message from failed call
     */
    function _getRevertMessage(bytes memory data) internal pure returns (string memory) {
        if (data.length < 68) return "Unknown error";
        assembly {
            data := add(data, 4)
        }
        return abi.decode(data, (string));
    }

    // ============================================================
    // =================== VIEW FUNCTIONS =========================
    // ============================================================

    /**
     * @notice Get comprehensive user details
     */
    function getUserFullDetails(address user) 
        external 
        view 
        returns (
            UserInfo memory info,
            uint256 currentBalance,
            uint256[] memory depAmounts,
            uint256[] memory depTimes,
            uint256[] memory withAmounts,
            uint256[] memory withTimes,
            uint256 avgBalance
        ) 
    {
        info = userInfo[user];
        currentBalance = info.totalDeposited - info.totalWithdrawn;
        depAmounts = depositAmounts[user];
        depTimes = depositTimestamps[user];
        withAmounts = withdrawalAmounts[user];
        withTimes = withdrawalTimestamps[user];
        avgBalance = timeWeightedAverageBalance[user];
    }

    /**
     * @notice Get all users (paginated)
     */
    function getUsers(uint256 start, uint256 end) external view returns (address[] memory) {
        uint256 length = _users.length();
        if (end > length) end = length;
        if (start >= end) return new address[](0);
        
        address[] memory usersList = new address[](end - start);
        for (uint256 i = start; i < end; i++) {
            usersList[i - start] = _users.at(i);
        }
        return usersList;
    }

    /**
     * @notice Get contract statistics
     */
    function getStats() 
        external 
        view 
        returns (
            uint256 totalUsers,
            uint256 totalDeposited_,
            uint256 totalWithdrawn_,
            uint256 totalFees_,
            uint256 totalReferrals_,
            uint256 vipUsers,
            uint256 contractBalance
        ) 
    {
        return (
            _users.length(),
            totalDeposited,
            totalWithdrawn,
            totalFeesCollected,
            totalReferralRewards,
            vipCount,
            address(this).balance
        );
    }

    /**
     * @notice Calculate projected fee for a user
     */
    function calculateProjectedFee(address user, uint256 amount) external view returns (uint256 fee, bool isVIP) {
        return _calculateFee(user, amount);
    }

    // ============================================================
    // =================== FALLBACK FUNCTIONS =====================
    // ============================================================

    receive() external payable {
        // Auto-deposit with no lock period and no referrer
        (uint256 fee, ) = _calculateFee(msg.sender, msg.value);
        uint256 netAmount = msg.value - fee;
        
        userInfo[msg.sender].totalDeposited += netAmount;
        totalDeposited += netAmount;
        totalFeesCollected += fee;
        
        emit Deposited(msg.sender, msg.value, fee, netAmount, block.timestamp, address(0));
    }
    
    fallback() external payable {
        revert("UltraAdvancedErrorsContract: invalid function call");
    }
}
