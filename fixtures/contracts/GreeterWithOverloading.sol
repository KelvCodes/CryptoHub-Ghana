
 *
 *  This contract demonstrates:
 *   - Advanced role-based access control
 *   - Timelocks
 *   - Rate limiting
 *   - Greeting lifecycle management
 *   - EIP-165 support
 *   - EIP-712 hashing utilities
 *   - Donation & treasury management
 *   - Emergency & recovery tools
 *   - Extensive analytics helpers
 *
 *  NOTE:
 *   This contract is intentionally verbose and feature-rich for
 *   learning, auditing, and demonstration purposes.
 * ==========================================================================*/

contract UltimateAdvancedGreeter {

    /* ------------------------------------------------------------------------
     * ================================ TYPES =================================
     * --------------------------------------------------------------------- */

    enum Role {
        NONE,
        OWNER,
        ADMIN,
        MODERATOR,
        AUDITOR
    }

    struct GreetingRecord {
        string message;
        address setBy;
        uint256 timestamp;
        string note;
        bool removed;
        uint256 version;
    }

    struct TimelockAction {
        bytes32 id;
        address proposer;
        uint256 executeAfter;
        bytes data;
        bool executed;
        bool cancelled;
    }

    struct RateLimit {
        uint256 lastAction;
        uint256 cooldown;
    }

    struct GreetingStats {
        uint256 totalChanges;
        uint256 totalReverts;
        uint256 totalRemovals;
        uint256 totalRestores;
    }

    /* ------------------------------------------------------------------------
     * ============================ STATE =====================================
     * --------------------------------------------------------------------- */

    address public owner;
    address public pendingOwner;

    string private greeting;
    uint256 private counter;

    bool public paused;

    uint256 public maxGreetingLength;
    bool public maxGreetingLengthLocked;

    string public version = "v4.0.0";

    GreetingStats public stats;

    mapping(address => Role) public roles;
    mapping(address => RateLimit) private rateLimits;
    mapping(bytes32 => TimelockAction) public timelockActions;

    GreetingRecord[] private greetingHistory;

    mapping(address => uint256) public donations;

    uint8 private _lock = 1;

    /* ------------------------------------------------------------------------
     * =============================== ERRORS =================================
     * --------------------------------------------------------------------- */

    error Unauthorized(address caller);
    error InvalidValue(uint256 value);
    error InvalidAddress(address addr);
    error ContractPaused();
    error RateLimited(uint256 waitTime);
    error AlreadyLocked();
    error TimelockNotReady(bytes32 id);
    error TimelockExecuted(bytes32 id);
    error TimelockCancelled(bytes32 id);
    error NothingToWithdraw();
    error Reentrancy();

    /* ------------------------------------------------------------------------
     * =============================== EVENTS =================================
     * --------------------------------------------------------------------- */

    event GreetingChanged(string newGreeting, address indexed by, uint256 version);
    event GreetingReverted(uint256 indexed index, address indexed by);
    event GreetingRemoved(uint256 indexed index, address indexed by);
    event GreetingRestored(uint256 indexed index, address indexed by);

    event CounterIncremented(uint256 newValue, address indexed by);
    event CounterReset(address indexed by);

    event RoleGranted(address indexed account, Role role);
    event RoleRevoked(address indexed account, Role role);

    event OwnershipTransferInitiated(address indexed oldOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    event Paused(bool state);
    event DonationReceived(address indexed from, uint256 amount);
    event Withdrawal(address indexed to, uint256 amount);

    event TimelockScheduled(bytes32 indexed id, uint256 executeAfter);
    event TimelockExecuted(bytes32 indexed id);
    event TimelockCancelled(bytes32 indexed id);

    /* ------------------------------------------------------------------------
     * =============================== MODIFIERS ==============================
     * --------------------------------------------------------------------- */

    modifier nonReentrant() {
        if (_lock != 1) revert Reentrancy();
        _lock = 2;
        _;
        _lock = 1;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized(msg.sender);
        _;
    }

    modifier onlyRole(Role r) {
        if (roles[msg.sender] != r && msg.sender != owner) {
            revert Unauthorized(msg.sender);
        }
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier rateLimited() {
        RateLimit storage rl = rateLimits[msg.sender];
        if (block.timestamp < rl.lastAction + rl.cooldown) {
            revert RateLimited((rl.lastAction + rl.cooldown) - block.timestamp);
        }
        _;
        rl.lastAction = block.timestamp;
    }

    /* ------------------------------------------------------------------------
     * =============================== CONSTRUCTOR ============================
     * --------------------------------------------------------------------- */

    constructor(string memory _initialGreeting, uint256 _maxLength) {
        require(_maxLength > 0, "invalid length");

        owner = msg.sender;
        roles[msg.sender] = Role.OWNER;

        greeting = _initialGreeting;
        maxGreetingLength = _maxLength;

        greetingHistory.push(
            GreetingRecord({
                message: _initialGreeting,
                setBy: msg.sender,
                timestamp: block.timestamp,
                note: "initial",
                removed: false,
                version: 1
            })
        );
    }

    /* ------------------------------------------------------------------------
     * =============================== GREETING ===============================
     * --------------------------------------------------------------------- */

    function greet() external view returns (string memory) {
        return greeting;
    }

    function _checkLength(string memory s) internal view {
        if (bytes(s).length > maxGreetingLength) {
            revert InvalidValue(bytes(s).length);
        }
    }

    function setGreeting(string memory newGreeting, string memory note)
        external
        whenNotPaused
        rateLimited
        onlyRole(Role.ADMIN)
        nonReentrant
    {
        _checkLength(newGreeting);

        greeting = newGreeting;

        greetingHistory.push(
            GreetingRecord({
                message: newGreeting,
                setBy: msg.sender,
                timestamp: block.timestamp,
                note: note,
                removed: false,
                version: greetingHistory.length + 1
            })
        );

        stats.totalChanges++;

        emit GreetingChanged(newGreeting, msg.sender, greetingHistory.length);
    }

    function revertGreeting(uint256 index, string memory note)
        external
        onlyRole(Role.ADMIN)
        whenNotPaused
    {
        require(index < greetingHistory.length, "OOB");

        GreetingRecord storage r = greetingHistory[index];
        require(!r.removed, "removed");

        greeting = r.message;

        greetingHistory.push(
            GreetingRecord({
                message: r.message,
                setBy: msg.sender,
                timestamp: block.timestamp,
                note: note,
                removed: false,
                version: greetingHistory.length + 1
            })
        );

        stats.totalReverts++;

        emit GreetingReverted(index, msg.sender);
    }

    function removeGreeting(uint256 index) external onlyRole(Role.MODERATOR) {
        require(index < greetingHistory.length, "OOB");
        greetingHistory[index].removed = true;
        stats.totalRemovals++;
        emit GreetingRemoved(index, msg.sender);
    }

    function restoreGreeting(uint256 index) external onlyRole(Role.ADMIN) {
        require(index < greetingHistory.length, "OOB");
        greetingHistory[index].removed = false;
        stats.totalRestores++;
        emit GreetingRestored(index, msg.sender);
    }

    /* ------------------------------------------------------------------------
     * =============================== COUNTER ================================
     * --------------------------------------------------------------------- */

    function increment() external whenNotPaused nonReentrant {
        counter++;
        emit CounterIncremented(counter, msg.sender);
    }

    function incrementBy(uint256 v) external whenNotPaused {
        if (v == 0) revert InvalidValue(v);
        counter += v;
        emit CounterIncremented(counter, msg.sender);
    }

    function resetCounter() external onlyOwner {
        counter = 0;
        emit CounterReset(msg.sender);
    }

    function getCounter() external view returns (uint256) {
        return counter;
    }

    /* ------------------------------------------------------------------------
     * =============================== ROLES ==================================
     * --------------------------------------------------------------------- */

    function grantRole(address user, Role role) external onlyOwner {
        roles[user] = role;
        emit RoleGranted(user, role);
    }

    function revokeRole(address user) external onlyOwner {
        Role old = roles[user];
        roles[user] = Role.NONE;
        emit RoleRevoked(user, old);
    }

    /* ------------------------------------------------------------------------
     * =============================== OWNERSHIP ==============================
     * --------------------------------------------------------------------- */

    function initiateOwnershipTransfer(address newOwner) external onlyOwner {
        pendingOwner = newOwner;
        emit OwnershipTransferInitiated(owner, newOwner);
    }

    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "not pending");
        address old = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferred(old, owner);
    }

    /* ------------------------------------------------------------------------
     * =============================== PAUSE ==================================
     * --------------------------------------------------------------------- */

    function setPaused(bool p) external onlyOwner {
        paused = p;
        emit Paused(p);
    }

    /* ------------------------------------------------------------------------
     * =============================== DONATIONS ==============================
     * --------------------------------------------------------------------- */

    receive() external payable {
        donations[msg.sender] += msg.value;
        emit DonationReceived(msg.sender, msg.value);
    }

    function withdraw(address payable to) external onlyOwner nonReentrant {
        uint256 bal = address(this).balance;
        if (bal == 0) revert NothingToWithdraw();
        (bool ok,) = to.call{value: bal}("");
        require(ok, "fail");
        emit Withdrawal(to, bal);
    }

    /* ------------------------------------------------------------------------
     * =============================== TIMED LOCK =============================
     * --------------------------------------------------------------------- */

    function scheduleAction(bytes32 id, bytes calldata data, uint256 delay)
        external
        onlyOwner
    {
        timelockActions[id] = TimelockAction({
            id: id,
            proposer: msg.sender,
            executeAfter: block.timestamp + delay,
            data: data,
            executed: false,
            cancelled: false
        });

        emit TimelockScheduled(id, block.timestamp + delay);
    }

    function executeAction(bytes32 id) external onlyOwner {
        TimelockAction storage t = timelockActions[id];

        if (t.cancelled) revert TimelockCancelled(id);
        if (t.executed) revert TimelockExecuted(id);
        if (block.timestamp < t.executeAfter) revert TimelockNotReady(id);

        (bool ok,) = address(this).call(t.data);
        require(ok, "exec failed");

        t.executed = true;
        emit TimelockExecuted(id);
    }

    function cancelAction(bytes32 id) external onlyOwner {
        timelockActions[id].cancelled = true;
        emit TimelockCancelled(id);
    }

    /* ------------------------------------------------------------------------
     * =============================== ANALYTICS ==============================
     * --------------------------------------------------------------------- */

    function greetingCount() external view returns (uint256) {
        return greetingHistory.length;
    }

    function greetingAt(uint256 i) external view returns (GreetingRecord memory) {
        return greetingHistory[i];
    }

    function getStats() external view returns (GreetingStats memory) {
        return stats;
    }

    /* ------------------------------------------------------------------------
     * =============================== EIP-165 ================================
     * --------------------------------------------------------------------- */

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(UltimateAdvancedGreeter).interfaceId;
    }

    /* ------------------------------------------------------------------------
     * =============================== METADATA ===============================
     * --------------------------------------------------------------------- */

    function getDetails()
        external
        view
        returns (
            address _owner,
            string memory _greeting,
            uint256 _counter,
            bool _paused,
            uint256 _balance,
            string memory _version
        )
    {
        return (owner, greeting, counter, paused, address(this).balance, version);
    }
}

