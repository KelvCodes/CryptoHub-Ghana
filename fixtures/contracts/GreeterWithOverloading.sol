s

    address public owner;

    /// @notice Pending owner used for two-step ownership transfer.
    address public pendingOwner;

    /// @notice Indicates whether the contract is paused.
    bool public paused;

    /// @notice Reasonable max greeting length (in bytes) enforced.
    uint256 public maxGreetingLength;

    /// @notice If true, the `maxGreetingLength` cannot be changed again.
    bool public maxGreetingLengthLocked;

    /// @notice Contract version (semantic minor).
    string public version = "v3.0.0";

    /// @notice Mapping for admin role addresses.
    mapping(address => bool) public admins;

    /// @notice Donation totals per address (who has donated ETH to the contract).
    mapping(address => uint256) public donations;

    // ------------------------------------------------------------------------
    // =========================== CUSTOM ERRORS ==============================
    // ------------------------------------------------------------------------

    error Unauthorized(address caller);
    error InvalidAddress(address provided);
    error InvalidValue(uint256 value);
    error ContractPaused();
    error MaxGreetingLengthExceeded(uint256 provided, uint256 maxAllowed);
    error ReentrancyGuard();
    error AlreadyLocked();
    error NothingToWithdraw();
    error NoPendingOwner();

    // ------------------------------------------------------------------------
    // ============================== EVENTS =================================
    // ------------------------------------------------------------------------

    event GreetingChanging(string indexed oldGreeting, string indexed newGreeting, address indexed changedBy);
    event GreetingChanged(string indexed newGreeting, address indexed changedBy, uint256 timestamp, string note);
    event GreetingReverted(uint256 indexed index, string indexed previousGreeting, address indexed revertedBy);
    event GreetingRemoved(uint256 indexed index, address indexed removedBy);
    event GreetingRestored(uint256 indexed index, address indexed restoredBy);
    event CounterIncremented(uint256 newValue, address indexed by);
    event CounterReset(uint256 newValue, address indexed by);
    event OwnershipTransferInitiated(address indexed currentOwner, address indexed pendingOwner);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    event ContractPausedState(bool isPaused, address indexed by);
    event DonationReceived(address indexed donor, uint256 amount);
    event Withdrawal(address indexed to, uint256 amount);
    event ERC20Withdrawal(address indexed token, address indexed to, uint256 amount);
    event MaxGreetingLengthUpdated(uint256 oldLength, uint256 newLength, address indexed by);
    event MaxGreetingLengthLocked(address indexed by);

    // ------------------------------------------------------------------------
    // ============================== STRUCTS =================================
    // ------------------------------------------------------------------------

    /// @notice Represents one greeting record in history.
    struct GreetingRecord {
        string message;
        address setBy;
        uint256 timestamp;
        string note; // optional human-readable note
        bool removed; // logical deletion flag
    }

    /// @notice All greetings ever set (initial greeting is recorded at deploy).
    GreetingRecord[] private greetingHistory;

    // ------------------------------------------------------------------------
    // ============================== GUARDS ==================================
    // ------------------------------------------------------------------------

    /// @dev Basic reentrancy guard.
    uint8 private _locked = 1;

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrancyGuard();
        _locked = 2;
        _;
        _locked = 1;
    }

    /// @dev Restricts function calls to the contract owner.
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized(msg.sender);
        _;
    }

    /// @dev Allows owner or admins to call.
    modifier onlyAdminOrOwner() {
        if (msg.sender != owner && !admins[msg.sender]) revert Unauthorized(msg.sender);
        _;
    }

    /// @dev Ensures that contract is not paused.
    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    /// @dev Ensures a non-zero address is passed.
    modifier notZeroAddress(address _addr) {
        if (_addr == address(0)) revert InvalidAddress(_addr);
        _;
    }

    // ------------------------------------------------------------------------
    // ============================= CONSTRUCTOR ==============================
    // ------------------------------------------------------------------------

    /// @notice Initializes the contract with an initial greeting and sets deployer as the owner.
    /// @param _greeting The initial greeting string.
    /// @param _maxGreetingLength Maximum allowed bytes length for a greeting (protects against huge strings).
    constructor(string memory _greeting, uint256 _maxGreetingLength) {
        require(_maxGreetingLength > 0, "max greeting length must be > 0");
        owner = msg.sender;
        greeting = _greeting;
        counter = 0;
        paused = false;
        maxGreetingLength = _maxGreetingLength;
        maxGreetingLengthLocked = false;

        // record initial greeting
        greetingHistory.push(GreetingRecord({
            message: _greeting,
            setBy: msg.sender,
            timestamp: block.timestamp,
            note: "initial greeting",
            removed: false
        }));
    }

    // ------------------------------------------------------------------------
    // ======================== GREETING FUNCTIONS ============================
    // ------------------------------------------------------------------------

    /// @notice Returns the current greeting.
    function greet() external view returns (string memory) {
        return greeting;
    }

    /// @notice Internal length-check helper (reverts if string bytes exceed max).
    function _ensureMaxLength(string memory _s) internal view {
        if (bytes(_s).length > maxGreetingLength) {
            revert MaxGreetingLengthExceeded(bytes(_s).length, maxGreetingLength);
        }
    }

    /// @notice Update greeting, record metadata, and emit events.
    /// @param _newGreeting The new greeting value.
    /// @return success True on success and updatedGreeting returned.
    function setGreeting(string memory _newGreeting)
        external
        onlyAdminOrOwner
        whenNotPaused
        nonReentrant
        returns (bool success, string memory updatedGreeting)
    {
        _ensureMaxLength(_newGreeting);
        if (keccak256(bytes(_newGreeting)) == keccak256(bytes(greeting))) {
            // No-op if same greeting
            return (true, greeting);
        }

        emit GreetingChanging(greeting, _newGreeting, msg.sender);
        greeting = _newGreeting;

        // push history record (note empty by default)
        greetingHistory.push(GreetingRecord({
            message: _newGreeting,
            setBy: msg.sender,
            timestamp: block.timestamp,
            note: "",
            removed: false
        }));

        emit GreetingChanged(_newGreeting, msg.sender, block.timestamp, "");
        return (true, _newGreeting);
    }

    /// @notice Overloaded: set greeting with note and optional event emission.
    function setGreeting(string memory _newGreeting, string memory _note, bool emitEvents)
        external
        onlyAdminOrOwner
        whenNotPaused
        nonReentrant
        returns (bool success, string memory updatedGreeting)
    {
        _ensureMaxLength(_newGreeting);
        string memory prev = greeting;

        if (emitEvents) emit GreetingChanging(prev, _newGreeting, msg.sender);
        greeting = _newGreeting;

        greetingHistory.push(GreetingRecord({
            message: _newGreeting,
            setBy: msg.sender,
            timestamp: block.timestamp,
            note: _note,
            removed: false
        }));

        if (emitEvents) emit GreetingChanged(_newGreeting, msg.sender, block.timestamp, _note);
        return (true, _newGreeting);
    }

    /// @notice Overloaded: set greeting by concatenating prefix, main, suffix.
    function setGreeting(
        string memory prefix,
        string memory _newGreeting,
        string memory suffix,
        string memory _note
    )
        external
        onlyAdminOrOwner
        whenNotPaused
        nonReentrant
        returns (bool success, string memory updatedGreeting)
    {
        // concatenate safely
        string memory full = string(abi.encodePacked(prefix, _newGreeting, suffix));
        _ensureMaxLength(full);

        emit GreetingChanging(greeting, full, msg.sender);
        greeting = full;

        greetingHistory.push(GreetingRecord({
            message: full,
            setBy: msg.sender,
            timestamp: block.timestamp,
            note: _note,
            removed: false
        }));

        emit GreetingChanged(full, msg.sender, block.timestamp, _note);
        return (true, full);
    }

    // ------------------------------------------------------------------------
    // ======================== COUNTER FUNCTIONS =============================
    // ------------------------------------------------------------------------

    /// @notice Increments the counter by 1.
    function increment() external whenNotPaused nonReentrant {
        counter += 1;
        emit CounterIncremented(counter, msg.sender);
    }

    /// @notice Overloaded: increments counter by a specific value.
    /// @param _value Value to add.
    function increment(uint256 _value) external whenNotPaused nonReentrant {
        if (_value == 0) revert InvalidValue(_value);
        counter += _value;
        emit CounterIncremented(counter, msg.sender);
    }

    /// @notice Overloaded: increments counter multiple times in a loop.
    /// @dev Use carefully: loops are bounded by `times`. Keep `times` small to avoid gas issues.
    function increment(uint256 _value, uint256 times) external whenNotPaused nonReentrant {
        if (_value == 0 || times == 0) revert InvalidValue(_value);
        // gas note: loops cost gas; callers should be mindful.
        for (uint256 i = 0; i < times; i++) {
            counter += _value;
        }
        emit CounterIncremented(counter, msg.sender);
    }

    /// @notice Returns the current counter value.
    function getCounter() external view returns (uint256) {
        return counter;
    }

    /// @notice Allows the owner to reset the counter to zero.
    function resetCounter() external onlyOwner nonReentrant {
        counter = 0;
        emit CounterReset(counter, msg.sender);
    }

    // ------------------------------------------------------------------------
    // ===================== OWNERSHIP, ADMIN & CONTROL =======================
    // ------------------------------------------------------------------------

    /// @notice Initiates a two-step ownership transfer.
    /// @param _newOwner The address to transfer ownership to.
    function initiateOwnershipTransfer(address _newOwner) external onlyOwner notZeroAddress(_newOwner) {
        pendingOwner = _newOwner;
        emit OwnershipTransferInitiated(owner, _newOwner);
    }

    /// @notice Accept ownership (callable by pending owner).
    function acceptOwnership() external nonReentrant {
        if (pendingOwner == address(0)) revert NoPendingOwner();
        if (msg.sender != pendingOwner) revert Unauthorized(msg.sender);

        address old = owner;
        owner = pendingOwner;
        pendingOwner = address(0);

        emit OwnershipTransferred(old, owner);
    }

    /// @notice Owner can directly renounce ownership (dangerous; use with care).
    function renounceOwnership() external onlyOwner {
        address old = owner;
        owner = address(0);
        emit OwnershipTransferred(old, address(0));
    }

    /// @notice Add an admin (owner only).
    function addAdmin(address _admin) external onlyOwner notZeroAddress(_admin) {
        admins[_admin] = true;
        emit AdminAdded(_admin);
    }

    /// @notice Remove an admin (owner only).
    function removeAdmin(address _admin) external onlyOwner {
        if (!admins[_admin]) revert InvalidAddress(_admin);
        admins[_admin] = false;
        emit AdminRemoved(_admin);
    }

    /// @notice Pauses or unpauses the contract (emergency stop).
    function togglePause(bool _paused) external onlyOwner {
        paused = _paused;
        emit ContractPausedState(_paused, msg.sender);
    }

    // ------------------------------------------------------------------------
    // =========================== GREETING HISTORY ===========================
    // ------------------------------------------------------------------------

    /// @notice Returns number of greeting records stored.
    function getGreetingCount() external view returns (uint256) {
        return greetingHistory.length;
    }

    /// @notice Returns a single greeting record by index.
    /// @param index Index in the greeting history array (0-based).
    function getGreetingRecord(uint256 index) external view returns (string memory message, address setBy, uint256 timestamp, string memory note, bool removed) {
        require(index < greetingHistory.length, "Index out of bounds");
        GreetingRecord storage r = greetingHistory[index];
        return (r.message, r.setBy, r.timestamp, r.note, r.removed);
    }

    /// @notice Returns a page of greeting records for safer on-chain enumeration.
    /// @dev Use pagination to avoid gas limits: provide `start` and `limit`.
    /// @param start Start index (inclusive).
    /// @param limit Maximum number of records to return.
    function getGreetingRecordsPaged(uint256 start, uint256 limit) external view returns (GreetingRecord[] memory records) {
        uint256 total = greetingHistory.length;
        if (start >= total) return new GreetingRecord;

        uint256 end = start + limit;
        if (end > total) end = total;

        uint256 size = end - start;
        records = new GreetingRecord[](size);
        for (uint256 i = 0; i < size; i++) {
            GreetingRecord storage r = greetingHistory[start + i];
            records[i] = GreetingRecord({
                message: r.message,
                setBy: r.setBy,
                timestamp: r.timestamp,
                note: r.note,
                removed: r.removed
            });
        }
        return records;
    }

    /// @notice Soft-remove a greeting from active view (keeps historical data).
    function removeGreeting(uint256 index) external onlyAdminOrOwner whenNotPaused nonReentrant {
        require(index < greetingHistory.length, "Index OOB");
        greetingHistory[index].removed = true;
        emit GreetingRemoved(index, msg.sender);
    }

    /// @notice Restore a previously removed greeting.
    function restoreGreeting(uint256 index) external onlyAdminOrOwner whenNotPaused nonReentrant {
        require(index < greetingHistory.length, "Index OOB");
        greetingHistory[index].removed = false;
        emit GreetingRestored(index, msg.sender);
    }

    /// @notice Revert to a previous greeting by index (makes it current and records a new history entry).
    /// @param index Index of the greeting to revert to.
    function revertToGreeting(uint256 index, string memory _note) external onlyAdminOrOwner whenNotPaused nonReentrant {
        require(index < greetingHistory.length, "Index OOB");
        GreetingRecord storage r = greetingHistory[index];
        require(!r.removed, "Cannot revert to removed greeting");
        string memory prev = greeting;
        greeting = r.message;

        greetingHistory.push(GreetingRecord({
            message: r.message,
            setBy: msg.sender,
            timestamp: block.timestamp,
            note: _note,
            removed: false
        }));

        emit GreetingChanging(prev, r.message, msg.sender);
        emit GreetingReverted(index, r.message, msg.sender);
        emit GreetingChanged(r.message, msg.sender, block.timestamp, _note);
    }

    // ------------------------------------------------------------------------
    // =========================== DONATIONS & WITHDRAW =======================
    // ------------------------------------------------------------------------

    /// @notice Receive ETH donations. Tracked per-sender.
    receive() external payable {
        if (msg.value > 0) {
            donations[msg.sender] += msg.value;
            emit DonationReceived(msg.sender, msg.value);
        }
    }

    fallback() external payable {
        if (msg.value > 0) {
            donations[msg.sender] += msg.value;
            emit DonationReceived(msg.sender, msg.value);
        }
    }

    /// @notice Owner withdraws all ETH from the contract.
    /// @param to Recipient address (cannot be zero).
    function withdrawETH(address payable to) external onlyOwner nonReentrant notZeroAddress(to) {
        uint256 bal = address(this).balance;
        if (bal == 0) revert NothingToWithdraw();
        (bool ok, ) = to.call{value: bal}("");
        require(ok, "Transfer failed");
        emit Withdrawal(to, bal);
    }

    /// @notice Minimal IERC20 interface for token withdrawals.
    interface IERC20 {
        function balanceOf(address account) external view returns (uint256);
        function transfer(address to, uint256 amount) external returns (bool);
    }

    /// @notice Owner withdraws ERC20 tokens accidentally sent to this contract.
    /// @param token Address of ERC20 token.
    /// @param to Recipient address.
    /// @param amount Amount to withdraw (use token.balanceOf if 0 to withdraw all).
    function withdrawERC20(address token, address to, uint256 amount) external onlyOwner nonReentrant notZeroAddress(to) {
        IERC20 t = IERC20(token);
        uint256 bal = t.balanceOf(address(this));
        uint256 sendAmount = amount == 0 ? bal : amount;
        require(sendAmount <= bal, "Insufficient token balance");
        bool ok = t.transfer(to, sendAmount);
        require(ok, "Token transfer failed");
        emit ERC20Withdrawal(token, to, sendAmount);
    }

    // ------------------------------------------------------------------------
    // =========================== SETTINGS HELPERS ===========================
    // ------------------------------------------------------------------------

    /// @notice Update the maximum allowed greeting bytes length.
    /// @param _newMax New max greeting length in bytes.
    function updateMaxGreetingLength(uint256 _newMax) external onlyOwner {
        if (maxGreetingLengthLocked) revert AlreadyLocked();
        if (_newMax == 0) revert InvalidValue(_newMax);
        uint256 old = maxGreetingLength;
        maxGreetingLength = _newMax;
        emit MaxGreetingLengthUpdated(old, _newMax, msg.sender);
    }

    /// @notice Lock the maxGreetingLength forever (irreversible).
    function lockMaxGreetingLength() external onlyOwner {
        if (maxGreetingLengthLocked) revert AlreadyLocked();
        maxGreetingLengthLocked = true;
        emit MaxGreetingLengthLocked(msg.sender);
    }

    // ------------------------------------------------------------------------
    // ============================= UTILITIES ================================
    // ------------------------------------------------------------------------

    /// @notice Returns a summary of the contract state.
    function getDetails()
        external
        view
        returns (
            address currentOwner,
            address currentPendingOwner,
            string memory currentGreeting,
            uint256 currentCounter,
            bool isPaused,
            uint256 greetingsStored,
            uint256 contractBalance
        )
    {
        return (owner, pendingOwner, greeting, counter, paused, greetingHistory.length, address(this).balance);
    }

    /// @notice Version bump helper (owner-only).
    function updateVersion(string memory _newVersion) external onlyOwner {
        version = _newVersion;
    }

    // ------------------------------------------------------------------------
    // =========================== NOTES & WARNINGS ===========================
    // ------------------------------------------------------------------------
    // - Avoid functions that iterate the *entire* `greetingHistory` on-chain when it
    //   grows large. Use `getGreetingRecordsPaged` for pagination from off-chain callers.
    // - Batch operations exist (e.g., looped increments) but be mindful of gas limits.
    // - This contract does not import OpenZeppelin to stay single-file, but for
    //   production consider using OZ's audited modules (Ownable, Pausable, ReentrancyGuard).
    // ------------------------------------------------------------------------
}

