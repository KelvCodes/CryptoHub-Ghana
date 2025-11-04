a solidity ^0.8.13;

/**
 * @title MsgSender
 * @dev A simple demonstration contract showing how to handle
 * message senders, string storage, and state updates in Solidity.
 */
contract MsgSender {
    // ======================================
    // 🔹 STATE VARIABLES
    // ======================================

    // Stores a string message.
    string public testString;

    // Tracks how many times the string has been updated.
    uint256 public updateCount;

    // Stores the address of the contract deployer (owner).
    address public owner;

    // ======================================
    // 🔹 EVENTS
    // ======================================

    // Event emitted when the string value is updated.
    event TestStringUpdated(
        address indexed updater,
        string oldValue,
        string newValue,
        uint256 updateNumber
    );

    // Event emitted when ownership is transferred.
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    // ======================================
    // 🔹 MODIFIERS
    // ======================================

    // Restricts certain functions to only the owner.
    modifier onlyOwner() {
        require(msg.sender == owner, "Access Denied: Not the owner");
        _;
    }

    // ======================================
    // 🔹 CONSTRUCTOR
    // ======================================

    /**
     * @dev Sets the initial test string and the contract owner.
     * @param _testString The initial string value.
     */
    constructor(string memory _testString) {
        testString = _testString;
        owner = msg.sender;
        updateCount = 0;
    }

    // ======================================
    // 🔹 READ FUNCTIONS
    // ======================================

    /**
     * @dev Returns the address of the message sender.
     */
    function from() public view returns (address) {
        return msg.sender;
    }

    /**
     * @dev Returns contract summary information.
     */
    function getSummary() public view returns (
        string memory currentString,
        uint256 totalUpdates,
        address currentOwner
    ) {
        return (testString, updateCount, owner);
    }

    // ======================================
    // 🔹 WRITE FUNCTIONS
    // ======================================

    /**
     * @dev Updates the stored testString value.
     * @param _testString The new string value to set.
     * @return success Boolean indicating successful update.
     * @return newString The updated string value.
     */
    function setTestString(string memory _testString)
        public
        onlyOwner
        returns (bool success, string memory newString)
    {
        string memory oldValue = testString;
        testString = _testString;
        updateCount++;

        emit TestStringUpdated(msg.sender, oldValue, _testString, updateCount);

        return (true, testString);
    }

    /**
     * @dev Transfers contract ownership to a new address.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Invalid address: zero address");
        address oldOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /**
     * @dev Resets the test string to an empty value.
     * @return success Boolean indicating successful reset.
     */
    function resetString() public onlyOwner returns (bool success) {
        string memory oldValue = testString;
        testString = "";
        updateCount++;

        emit TestStringUpdated(msg.sender, oldValue, testString, updateCount);
        return true;
    }
}

