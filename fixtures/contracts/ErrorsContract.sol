ct {ErrorsContract";
    string public constant CONTRACT_VERSION = "2.0";

    address payable public owner;

    /// @notice Pause switch for emergency stop
    bool public paused;

    /// @notice Basic global deposit statistics
    uint256 public totalDeposited;
    uint256 public totalWithdrawn;
    uint256 public totalUsers;

    /// @notice Reentrancy guard status
    bool private locked;

    /// @notice Fee percentage (e.g., 100 = 1%)
    uint256 public feeBasisPoints = 50; // 0.5% default

    /// @notice Tracks each user's deposits
    mapping(address => uint256) public deposits;

    /// @notice Records timestamps of each user's last deposit
    mapping(address => uint256) public lastDepositAt;

    // ============================================================
    // ======================= ERRORS ==============================
    // ============================================================

    error Unauthorized(address caller);
    error CustomError(string message);
    error TransferFailed(uint256 amount, address to);
    error ContractPaused();
    error ReentrancyDetected();

    // ============================================================
    // ======================= EVENTS ==============================
    // ============================================================

    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event FeeUpdated(uint256 oldFee, uint256 newFee);

    event Deposited(address indexed from, uint256 amount);
    event UserWithdrawn(address indexed user, uint256 amount);
    event OwnerWithdrawn(address indexed owner, uint256 amount);

    event Paused(address indexed by);
    event Unpaused(address indexed by);

    event EmergencyDrain(address indexed by, uint256 amount);

    // ============================================================
    // ======================= MODIFIERS ==========================
    // ============================================================

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized(msg.sender);
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
    // =================== DEPOSITING LOGIC ========================
    // ============================================================

    /// @notice Deposit Ether with a minimum requirement
    function deposit() external payable whenNotPaused nonReentrant {
        if (msg.value < 0.01 ether) revert CustomError("Minimum deposit is 0.01 ETH");

        if (deposits[msg.sender] == 0) totalUsers++;

        deposits[msg.sender] += msg.value;
        lastDepositAt[msg.sender] = block.timestamp;
        totalDeposited += msg.value;

        emit Deposited(msg.sender, msg.value);
    }

    receive() external payable {
        deposits[msg.sender] += msg.value;
        lastDepositAt[msg.sender] = block.timestamp;
        totalDeposited += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    fallback() external payable {
        deposits[msg.sender] += msg.value;
        lastDepositAt[msg.sender] = block.timestamp;
        totalDeposited += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    // ============================================================
    // =================== USER WITHDRAWALS =======================
    // ============================================================

    /// @notice Users withdraw their own funds
    function userWithdraw(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert CustomError("Amount must be greater than zero");
        if (amount > deposits[msg.sender]) revert CustomError("Insufficient balance");

        deposits[msg.sender] -= amount;
        totalWithdrawn += amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed(amount, msg.sender);

        emit UserWithdrawn(msg.sender, amount);
    }

    /// @notice Withdraw all user funds
    function userWithdrawAll() external nonReentrant whenNotPaused {
        uint256 amount = deposits[msg.sender];
        if (amount == 0) revert CustomError("You have no funds");

        deposits[msg.sender] = 0;
        totalWithdrawn += amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed(amount, msg.sender);

        emit UserWithdrawn(msg.sender, amount);
    }

    // ============================================================
    // ================= OWNER WITHDRAWALS =========================
    // ============================================================

    function withdrawAll() external onlyOwner whenNotPaused nonReentrant {
        uint256 balance = address(this).balance;
        if (balance == 0) revert CustomError("No funds to withdraw");

        (bool success, ) = owner.call{value: balance}("");
        if (!success) revert TransferFailed(balance, owner);

        emit OwnerWithdrawn(owner, balance);
    }

    function withdrawPartial(uint256 amount)
        external
        onlyOwner
        whenNotPaused
        nonReentrant
    {
        uint256 balance = address(this).balance;
        if (amount == 0 || amount > balance)
            revert CustomError("Invalid withdrawal amount");

        (bool success, ) = owner.call{value: amount}("");
        if (!success) revert TransferFailed(amount, owner);

        emit OwnerWithdrawn(owner, amount);
    }

    // ============================================================
    // ======================= EMERGENCY ===========================
    // ============================================================

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    /// @notice Emergency drain (only when paused)
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

    function updateFee(uint256 newFee) external onlyOwner {
        if (newFee > 1000) revert CustomError("Fee too high");
        emit FeeUpdated(feeBasisPoints, newFee);
        feeBasisPoints = newFee;
    }

    // ============================================================
    // ====================== VIEW HELPERS =========================
    // ============================================================

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getUserDetails(address user)
        external
        view
        returns (uint256 depositAmount, uint256 lastDeposit)
    {
        return (deposits[user], lastDepositAt[user]);
    }

    function getStats()
        external
        view
        returns (uint256 totalUsers_, uint256 deposited, uint256 withdrawn)
    {
        return (totalUsers, totalDeposited, totalWithdrawn);
    }
}

