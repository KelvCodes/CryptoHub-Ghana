
    }w returns (uint256) {
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
