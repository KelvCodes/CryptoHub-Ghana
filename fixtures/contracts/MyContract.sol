nd history tracking.
 */
contract MyContract {
    // ======================================
    // STATE VARIABLES
    // ======================================

    string private myAttribute;             // Stores the main attribute string
    address public owner;                   // Contract deployer (owner)
    string[] private attributeHistory;      // History of all attribute updates

    // ======================================
    // CUSTOM ERRORS
    // ======================================

    error Unauthorized(address caller);
    error EmptyString();

    // ======================================
    // EVENTS
    // ======================================

    event AttributeUpdated(address indexed updater, string oldValue, string newValue);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    // ======================================
    // MODIFIERS
    // ======================================

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized(msg.sender);
        _;
    }

    // ======================================
    // CONSTRUCTOR
    // ======================================

    constructor(string memory initialValue) {
        if (bytes(initialValue).length == 0) revert EmptyString();
        myAttribute = initialValue;
        owner = msg.sender;
        attributeHistory.push(initialValue);
    }

    // ======================================
    // PUBLIC VIEW FUNCTIONS
    // ======================================

    /// @notice Returns the current value of the attribute
    function getAttr() public view returns (string memory) {
        return myAttribute;
    }

    /// @notice Returns the full history of attribute updates
    function getHistory() public view returns (string[] memory) {
        return attributeHistory;
    }

    // ======================================
    // WRITE FUNCTIONS
    // ======================================

    /// @notice Updates the attribute value
    /// @param newValue The new string value to set
    function setAttr(string memory newValue) public onlyOwner {
        if (bytes(newValue).length == 0) revert EmptyString();

        string memory oldValue = myAttribute;
        myAttribute = newValue;
        attributeHistory.push(newValue);

        emit AttributeUpdated(msg.sender, oldValue, newValue);
    }

    /// @notice Overloaded version of setAttr with optional event emission
    /// @param newValue The new string value
    /// @param emitEvent If true, emits the AttributeUpdated event
    function setAttr(string memory newValue, bool emitEvent) public onlyOwner {
        if (bytes(newValue).length == 0) revert EmptyString();

        string memory oldValue = myAttribute;
        myAttribute = newValue;
        attributeHistory.push(newValue);

        if (emitEvent) {
            emit AttributeUpdated(msg.sender, oldValue, newValue);
        }
    }

    // ======================================
    // OWNER MANAGEMENT
    // ======================================

    /// @notice Transfers contract ownership to a new address
    /// @param newOwner The new owner address
    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner == address(0)) revert Unauthorized(newOwner);

        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

