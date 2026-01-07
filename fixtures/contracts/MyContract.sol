
    event OwnershipT indexed by);
    event AttributeLockedEvent(uint256 until);
    event AttributeUnlockedEvent();

    // ======================================
    // MODIFIERS
    // ======================================
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized(msg.sender);
        _;
    }

    modifier notPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier notLocked() {
        if (block.timestamp < lockUntil) revert AttributeLocked(lockUntil);
        _;
    }

    // ======================================
    // CONSTRUCTOR
    // ======================================
    constructor(string memory initialValue) {
        if (bytes(initialValue).length == 0) revert EmptyString();
        owner = msg.sender;
        myAttribute = initialValue;
        lastUpdated = block.timestamp;
        attributeHistory.push(HistoryEntry(initialValue, block.timestamp));
    }

    // ======================================
    // VIEW FUNCTIONS
    // ======================================

    /// @notice Returns the current attribute value
    function getAttr() public view returns (string memory) {
        return myAttribute;
    }

    /// @notice Returns the entire history of attribute updates with timestamps
    function getHistory() public view returns (HistoryEntry[] memory) {
        return attributeHistory;
    }

    /// @notice Returns the last updated timestamp
    function getLastUpdateTime() public view returns (uint256) {
        return lastUpdated;
    }

    /// @notice Compares two strings for equality
    function compareStrings(string memory a, string memory b) public pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    // ======================================
    // WRITE FUNCTIONS
    // ======================================

    /// @notice Updates the attribute value with event emission
    function setAttr(string memory newValue) public onlyOwner notPaused notLocked {
        if (bytes(newValue).length == 0) revert EmptyString();

        string memory oldValue = myAttribute;
        myAttribute = newValue;
        lastUpdated = block.timestamp;
        attributeHistory.push(HistoryEntry(newValue, block.timestamp));

        emit AttributeUpdated(msg.sender, oldValue, newValue, block.timestamp);
    }

    /// @notice Overloaded version with optional event emission
    function setAttr(string memory newValue, bool emitEvent) public onlyOwner notPaused notLocked {
        if (bytes(newValue).length == 0) revert EmptyString();

        string memory oldValue = myAttribute;
        myAttribute = newValue;
        lastUpdated = block.timestamp;
        attributeHistory.push(HistoryEntry(newValue, block.timestamp));

        if (emitEvent) {
            emit AttributeUpdated(msg.sender, oldValue, newValue, block.timestamp);
        }
    }

    // ======================================
    // CONTRACT CONTROL FUNCTIONS
    // ======================================

    /// @notice Pause the contract (disable updates)
    function pause() external onlyOwner {
        paused = true;
        emit ContractPaused(msg.sender);
    }

    /// @notice Unpause the contract
    function unpause() external onlyOwner {
        paused = false;
        emit ContractUnpaused(msg.sender);
    }

    /// @notice Lock updates for a specified duration (in seconds)
    function lockAttribute(uint256 duration) external onlyOwner {
        lockUntil = block.timestamp + duration;
        emit AttributeLockedEvent(lockUntil);
    }

    /// @notice Unlock attribute manually before time
    function unlockAttribute() external onlyOwner {
        lockUntil = 0;
        emit AttributeUnlockedEvent();
    }

    // ======================================
    // OWNER MANAGEMENT
    // ======================================

    /// @notice Transfers ownership to a new address
    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner == address(0)) revert Unauthorized(newOwner);
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    // ======================================
    // FALLBACKS
    // ======================================

    receive() external payable {
        // Accept ETH just for demonstration
    }

    fallback() external payable {
        // Handles calls to non-existent functions
    }
}
