s, secure Ether handling, deposit tracking, partial withdrawals,
 * ownership control, and emergency pause functionality.
 * @dev Designed for learning safe Ether management and advanced Solidity practices.
 */
contract AdvancedErrorsContract {
    // =============================
    // ======== STATE VARIABLES =====
    // =============================

    /// @notice Contract owner address
    address payable public owner;

    /// @notice Tracks if contract operations are paused
    bool public paused;

    /// @notice Tracks user deposits
    mapping(address => uint256) public deposits;

    // =============================
    // ======== CUSTOM ERRORS ======
    // =============================

    error Unauthorized(address caller);
    error CustomError(string message);
    error TransferFailed(uint256 amount, address to);
    error ContractPaused();

    // =============================
    // ========= EVENTS ===========
    // =============================

    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event FundsTransferred(address indexed to, uint256 amount);
    event Deposited(address indexed from, uint256 amount);
    event Paused(address indexed by);
    event Unpaused(address indexed by);

    // =============================
    // ======== MODIFIERS =========
    // =============================

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized(msg.sender);
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    // =============================
    // ======== CONSTRUCTOR =======
    // =============================

    /// @notice Sets deployer as initial owner
    constructor() {
        owner = payable(msg.sender);
        emit OwnershipTransferred(address(0), owner);
    }

    // =============================
    // ======== OWNER FUNCTIONS ====
    // =============================

    /// @notice Withdraw all Ether from the contract to the owner
    function withdrawAll() external onlyOwner whenNotPaused {
        uint256 balance = address(this).balance;
        if (balance == 0) revert CustomError("No funds to withdraw");

        (bool success, ) = owner.call{value: balance}("");
        if (!success) revert TransferFailed(balance, owner);

        emit FundsTransferred(owner, balance);
    }

    /// @notice Withdraw a specific amount to the owner
    /// @param amount Amount in wei to withdraw
    function withdrawPartial(uint256 amount) external onlyOwner whenNotPaused {
        uint256 balance = address(this).balance;
        if (amount == 0 || amount > balance) revert CustomError("Invalid withdrawal amount");

        (bool success, ) = owner.call{value: amount}("");
        if (!success) revert TransferFailed(amount, owner);

        emit FundsTransferred(owner, amount);
    }

    /// @notice Update contract ownership
    /// @param newOwner New owner address
    function updateOwner(address payable newOwner) external onlyOwner {
        if (newOwner == address(0)) revert CustomError("Cannot set zero address as owner");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Pause contract functions in emergencies
    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    /// @notice Unpause contract
    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    // =============================
    // ======== USER FUNCTIONS =====
    // =============================

    /// @notice Deposit Ether into the contract
    /// @dev Minimum deposit of 0.01 Ether
    function deposit() external payable whenNotPaused {
        if (msg.value < 0.01 ether) revert CustomError("Minimum deposit is 0.01 ETH");
        deposits[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    // =============================
    // ======== FALLBACK / RECEIVE ==
    // =============================

    receive() external payable {
        deposits[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    fallback() external payable {
        deposits[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    // =============================
    // ======== HELPER FUNCTIONS ===
    // =============================

    /// @notice Get contract balance
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Get a user's total deposits
    /// @param user Address to check deposits for
    function getUserDeposits(address user) external view returns (uint256) {
        return deposits[user];
    }

    /// @notice Demonstrates custom error
    function badRequire() external pure {
        if (1 < 2) revert CustomError("Reverted using custom error");
    }
}

