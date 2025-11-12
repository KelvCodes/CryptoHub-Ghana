Value;
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

