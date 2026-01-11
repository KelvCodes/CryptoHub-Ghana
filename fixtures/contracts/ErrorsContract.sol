// SPDX-License-Identifier: GNU
pragma solidity ^0.8.13;

/**
 * @title UltraAdvancedErrorsContract
 * @author Kelvin
 * @notice Master-level Solidity example featuring:
 * - Custom errors
 * - Deposit tracking + per-user histories
 * - User withdrawals
 * - Owner partial/full withdrawals
 * - Emergency pause system
 * - Manual reentrancy guard
 * - Token recovery
 * - Fees
 * - Ownership control
 * - Secure Ether flow
 * - Global analytics
 * - Time-based deposits
 * - Multi-admin support
 * @dev Perfect for learning secure, production-grade contract architecture.
 */
contract UltraAdvancedErrorsContract {

    // ============================================================
    // ======================= STATE ==============================
    // ============================================================

    string public constant CONTRACT_NAME = "UltraAdvancedErrorsContract";
    string public constant CONTRACT_VERSION = "3.0";

    address payable public owner;

    /// @notice Multiple admin mapping
    mapping(address => bool) public admins;

    /// @notice Pause switch for emergency stop
    bool public paused;

    /// @notice Basic global deposit statistics
    uint256 public totalDeposited;
    uint256 public totalWithdrawn;
    uint256 public totalUsers;
    uint256 public totalFeesCollected;

    /// @notice Reentrancy guard status
    bool private locked;

    /// @notice Fee percentage (e.g., 100 = 1%)
    uint256 public feeBasisPoints = 50; // 0.5% default

    /// @notice Tracks each user's deposits
    mapping(address => uint256) public deposits;

    /// @notice Tracks each user's withdrawal totals
    mapping(address => uint256) public withdrawals;

    /// @notice Records timestamps of each user's last deposit
    mapping(address => uint256) public lastDepositAt;

    /// @notice Stores detailed deposit history per user
    mapping(address => uint256[]) public depositHistory;

    /// @notice Stores detailed withdrawal history per user
    mapping(address => uint256[]) public withdrawalHistory;

    /// @notice Tracks locked deposits (time-based)
    mapping(address => uint256) public depositLockUntil;

    // ============================================================
    // ======================= ERRORS =============================
    // ============================================================

    error Unauthorized(address caller);
    error CustomError(string message);
    error TransferFailed(uint256 amount, address to);
    error ContractPaused();
    error ReentrancyDetected();
    error AdminExists(address admin);
    error AdminNotFound(address admin);

    // ============================================================
    // ======================= EVENTS =============================
    // ============================================================

    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);

    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event Deposited(address indexed from, uint256 amount, uint256 fee);
    event UserWithdrawn(address indexed user, uint256 amount, uint256 fee);
    event OwnerWithdrawn(address indexed owner, uint256 amount);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event EmergencyDrain(address indexed by, uint256 amount);
    event DepositLocked(address indexed user, uint256 until);

    // ============================================================
    // ======================= MODIFIERS ==========================
    // ============================================================

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized(msg.sender);
        _;
    }

    modifier onlyAdmin() {
        if (!admins[msg.sender] && msg.sender != owner) revert Unauthorized(msg.sender);
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier nonReentrant() {
        if (locked) revert ReentrancyDetected();
        locked = true;
        _;
        locked = false;
    }

    // ============================================================
    // ====================== CONSTRUCTOR =========================
    // ============================================================

    constructor() {
        owner = payable(msg.sender);
        emit OwnershipTransferred(address(0), owner);
    }

    // ============================================================
    // =================== DEPOSITING LOGIC =======================
    // ============================================================

    /// @notice Deposit Ether with a minimum requirement and optional lock period
    function deposit(uint256 lockSeconds) external payable whenNotPaused nonReentrant {
        if (msg.value < 0.01 ether) revert CustomError("Minimum deposit is 0.01 ETH");

        uint256 fee = (msg.value * feeBasisPoints) / 10000;
        uint256 amountAfterFee = msg.value - fee;

        totalFeesCollected += fee;

        if (deposits[msg.sender] == 0) totalUsers++;

        deposits[msg.sender] += amountAfterFee;
        depositHistory[msg.sender].push(amountAfterFee);
        lastDepositAt[msg.sender] = block.timestamp;

        if (lockSeconds > 0) {
            depositLockUntil[msg.sender] = block.timestamp + lockSeconds;
            emit DepositLocked(msg.sender, depositLockUntil[msg.sender]);
        }

        totalDeposited += amountAfterFee;

        emit Deposited(msg.sender, amountAfterFee, fee);
    }

    receive() external payable {
        deposits[msg.sender] += msg.value;
        depositHistory[msg.sender].push(msg.value);
        lastDepositAt[msg.sender] = block.timestamp;
        totalDeposited += msg.value;
        emit Deposited(msg.sender, msg.value, 0);
    }

    fallback() external payable {
        deposits[msg.sender] += msg.value;
        depositHistory[msg.sender].push(msg.value);
        lastDepositAt[msg.sender] = block.timestamp;
        totalDeposited += msg.value;
        emit Deposited(msg.sender, msg.value, 0);
    }

    // ============================================================
    // =================== USER WITHDRAWALS =======================
    // ============================================================

    function userWithdraw(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert CustomError("Amount must be greater than zero");
        if (amount > deposits[msg.sender]) revert CustomError("Insufficient balance");
        if (block.timestamp < depositLockUntil[msg.sender]) revert CustomError("Deposit is locked");

        uint256 fee = (amount * feeBasisPoints) / 10000;
        uint256 payout = amount - fee;

        deposits[msg.sender] -= amount;
        withdrawals[msg.sender] += payout;
        withdrawalHistory[msg.sender].push(payout);
        totalWithdrawn += payout;
        totalFeesCollected += fee;

        (bool success, ) = payable(msg.sender).call{value: payout}("");
        if (!success) revert TransferFailed(payout, msg.sender);

        emit UserWithdrawn(msg.sender, payout, fee);
    }

    function userWithdrawAll() external nonReentrant whenNotPaused {
        uint256 amount = deposits[msg.sender];
        if (amount == 0) revert CustomError("You have no funds");
        if (block.timestamp < depositLockUntil[msg.sender]) revert CustomError("Deposit is locked");

        uint256 fee = (amount * feeBasisPoints) / 10000;
        uint256 payout = amount - fee;

        deposits[msg.sender] = 0;
        withdrawals[msg.sender] += payout;
        withdrawalHistory[msg.sender].push(payout);
        totalWithdrawn += payout;
        totalFeesCollected += fee;

        (bool success, ) = payable(msg.sender).call{value: payout}("");
        if (!success) revert TransferFailed(payout, msg.sender);

        emit UserWithdrawn(msg.sender, payout, fee);
    }

    // ============================================================
    // ================= OWNER WITHDRAWALS ========================
    // ============================================================

    function withdrawAll() external onlyOwner whenNotPaused nonReentrant {
        uint256 balance = address(this).balance;
        if (balance == 0) revert CustomError("No funds to withdraw");

        (bool success, ) = owner.call{value: balance}("");
        if (!success) revert TransferFailed(balance, owner);

        emit OwnerWithdrawn(owner, balance);
    }

    function withdrawPartial(uint256 amount) external onlyOwner whenNotPaused nonReentrant {
        uint256 balance = address(this).balance;
        if (amount == 0 || amount > balance) revert CustomError("Invalid withdrawal amount");

        (bool success, ) = owner.call{value: amount}("");
        if (!success) revert TransferFailed(amount, owner);

        emit OwnerWithdrawn(owner, amount);
    }

    // ============================================================
    // ======================= EMERGENCY ==========================
    // ============================================================

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function emergencyDrain() external onlyOwner {
        if (!paused) revert CustomError("Must be paused");

        uint256 amount = address(this).balance;

        (bool success, ) = owner.call{value: amount}("");
        if (!success) revert TransferFailed(amount, owner);

        emit EmergencyDrain(msg.sender, amount);
    }

    // ============================================================
    // ======================= ADMIN ==============================
    // ============================================================

    function updateOwner(address payable newOwner) external onlyOwner {
        if (newOwner == address(0)) revert CustomError("Zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function addAdmin(address admin) external onlyOwner {
        if (admins[admin]) revert AdminExists(admin);
        admins[admin] = true;
        emit AdminAdded(admin);
    }

    function removeAdmin(address admin) external onlyOwner {
        if (!admins[admin]) revert AdminNotFound(admin);
        admins[admin] = false;
        emit AdminRemoved(admin);
    }

    function updateFee(uint256 newFee) external onlyOwner {
        if (newFee > 1000) revert CustomError("Fee too high");
        emit FeeUpdated(feeBasisPoints, newFee);
        feeBasisPoints = newFee;
    }

    // ============================================================
    // ====================== TOKEN RECOVERY ======================
    // ============================================================

    function recoverERC20(address tokenAddress, uint256 amount) external onlyOwner {
        IERC20(tokenAddress).transfer(owner, amount);
    }

    // ============================================================
    // ====================== VIEW HELPERS ========================
    // ============================================================

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getUserDetails(address user) external view returns (
        uint256 depositAmount,
        uint256 lastDeposit,
        uint256 totalWithdrawnUser,
        uint256 lockUntil
    ) {
        return (deposits[user], lastDepositAt[user], withdrawals[user], depositLockUntil[user]);
    }

    function getUserDepositHistory(address user) external view returns (uint256[] memory) {
        return depositHistory[user];
    }

    function getUserWithdrawalHistory(address user) external view returns (uint256[] memory) {
        return withdrawalHistory[user];
    }

    function getStats() external view returns (
        uint256 totalUsers_,
        uint256 deposited,
        uint256 withdrawn,
        uint256 feesCollected
    ) {
        return (totalUsers, totalDeposited, totalWithdrawn, totalFeesCollected);
    }
}

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
}
