
 */
contract AdvancedMsgSender {
    // =========================================================
    //  STATE VARIABLES
    // =========================================================

    string public testString;
    uint256 public updateCount;
    address public owner;
    bool public paused;

    // Array to track the history of all past messages.
    string[] private updateHistory;

    // Mapping to store the timestamp of each update.
    mapping(uint256 => uint256) private updateTimestamps;

    // =========================================================
    //  CUSTOM ERRORS (Gas-efficient alternative to require)
    // =========================================================

    error Unauthorized(address caller);
    error InvalidAddress(address provided);
    error ContractPaused();
    error EmptyStringNotAllowed();
    error NoPreviousValue();

    // =========================================================
    //  EVENTS
    // =========================================================

    event TestStringUpdated(
        address indexed updater,
        string oldValue,
        string newValue,
        uint256 updateNumber,
        uint256 timestamp
    );

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ContractPausedState(bool isPaused);
    event StringReset(address indexed triggeredBy, uint256 resetAt);
    event StringRestored(address indexed triggeredBy, string restoredValue);

    // =========================================================
    //  MODIFIERS
    // =========================================================

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized(msg.sender);
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    // =========================================================
    //  CONSTRUCTOR
    // =========================================================

    /**
     * @dev Initializes the contract with an initial message and sets the deployer as the owner.
     * @param _initialString The initial message string.
     */
    constructor(string memory _initialString) {
        if (bytes(_initialString).length == 0) revert EmptyStringNotAllowed();
        testString = _initialString;
        owner = msg.sender;
        updateCount = 0;
        paused = false;

        updateHistory.push(_initialString);
        updateTimestamps[updateCount] = block.timestamp;
    }

    // =========================================================
    //  READ FUNCTIONS
    // =========================================================

    /// @notice Returns the address that called the function.
    function from() external view returns (address) {
        return msg.sender;
    }

    /// @notice Returns a contract summary including message, count, and owner.
    function getSummary()
        external
        view
        returns (string memory currentString, uint256 totalUpdates, address currentOwner, bool isPaused)
    {
        return (testString, updateCount, owner, paused);
    }

    /// @notice Returns all past messages in history.
    function getHistory() external view returns (string[] memory) {
        return updateHistory;
    }

    /// @notice Returns timestamp of a specific update.
    function getUpdateTimestamp(uint256 index) external view returns (uint256) {
        require(index <= updateCount, "Invalid update index");
        return updateTimestamps[index];
    }

    // =========================================================
    //  WRITE FUNCTIONS
    // =========================================================

    /**
     * @dev Updates the stored message string (standard version).
     * @param _newString The new string value to store.
     */
    function setTestString(string memory _newString)
        external
        onlyOwner
        whenNotPaused
        returns (bool success, string memory newString)
    {
        if (bytes(_newString).length == 0) revert EmptyStringNotAllowed();

        string memory oldValue = testString;
        testString = _newString;
        updateCount++;

        updateHistory.push(_newString);
        updateTimestamps[updateCount] = block.timestamp;

        emit TestStringUpdated(msg.sender, oldValue, _newString, updateCount, block.timestamp);
        return (true, _newString);
    }

    /**
     * @dev Overloaded version that can optionally skip event emission.
     * @param _newString The new string.
     * @param emitEvent If true, emits the update event.
     */
    function setTestString(string memory _newString, bool emitEvent)
        external
        onlyOwner
        whenNotPaused
        returns (bool success, string memory newString)
    {
        if (bytes(_newString).length == 0) revert EmptyStringNotAllowed();

        string memory oldValue = testString;
        testString = _newString;
        updateCount++;

        updateHistory.push(_newString);
        updateTimestamps[updateCount] = block.timestamp;

        if (emitEvent) {
            emit TestStringUpdated(msg.sender, oldValue, _newString, updateCount, block.timestamp);
        }

        return (true, _newString);
    }

    /**
     * @dev Resets the message string to empty ("").
     */
    function resetString() external onlyOwner whenNotPaused returns (bool) {
        string memory oldValue = testString;
        testString = "";
        updateCount++;
        updateHistory.push("");
        updateTimestamps[updateCount] = block.timestamp;

        emit TestStringUpdated(msg.sender, oldValue, testString, updateCount, block.timestamp);
        emit StringReset(msg.sender, block.timestamp);
        return true;
    }

    /**
     * @dev Restores the last saved string value from history.
     */
    function restoreLastString() external onlyOwner whenNotPaused returns (bool) {
        if (updateHistory.length < 2) revert NoPreviousValue();

        string memory previousValue = updateHistory[updateHistory.length - 2];
        testString = previousValue;
        updateCount++;

        updateHistory.push(previousValue);
        updateTimestamps[updateCount] = block.timestamp;

        emit StringRestored(msg.sender, previousValue);
        emit TestStringUpdated(msg.sender, "", previousValue, updateCount, block.timestamp);
        return true;
    }

    // =========================================================
    //  OWNER MANAGEMENT
    // =========================================================

    /**
     * @dev Transfers ownership to a new address.
     * @param newOwner The address of the new owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidAddress(newOwner);
        address oldOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /**
     * @dev Pauses or unpauses the contract for emergency control.
     * @param _paused True to pause, false to unpause.
     */
    function togglePause(bool _paused) external onlyOwner {
        paused = _paused;
        emit ContractPausedState(_paused);
    }

    /**
     * @dev Deletes all string history (irreversible). Use cautiously.
     */
    function clearHistory() external onlyOwner {
        delete updateHistory;
        emit TestStringUpdated(msg.sender, "CLEARED_HISTORY", "", updateCount, block.timestamp);
    }

    // =========================================================
    //  VIEW UTILITIES.
    // =========================================================

    /// @notice Returns full contract details for UI integration or monitoring.
    function getDetails()
        external
        view
        returns (
            string memory currentString,
            uint256 totalUpdates,
            address currentOwner,
            bool isPaused,
            uint256 lastUpdatedAt
        )
    {
        return (testString, updateCount, owner, paused, updateTimestamps[updateCount]);
    }
}

