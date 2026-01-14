

    // ============================================================
    // 🔹 CONSTRUCTOR
    // ============================================================

    constructor(string memory initialValue) {
        if (bytes(initialValue).length == 0) revert EmptyString();

        owner = msg.sender;
        _setAttribute(initialValue);

        lastUpdated = block.timestamp;
        history.push(
            HistoryEntry(
                initialValue,
                _attributeHash,
                block.timestamp,
                msg.sender
            )
        );
    }

    // ============================================================
    // 🔹 INTERNAL CORE LOGIC
    // ============================================================

    function _setAttribute(string memory newValue) internal {
        _attribute = newValue;
        _attributeHash = keccak256(abi.encodePacked(newValue));
        lastUpdated = block.timestamp;
        lastUpdateAttempt = block.timestamp;
    }

    function _validateIntegrity(string memory value) internal view {
        if (keccak256(abi.encodePacked(value)) != _attributeHash) {
            revert IntegrityMismatch();
        }
    }

    // ============================================================
    // 🔹 VIEW FUNCTIONS
    // ============================================================

    function getAttribute() external view returns (string memory) {
        return _attribute;
    }

    function getAttributeHash() external view returns (bytes32) {
        return _attributeHash;
    }

    function verifyIntegrity() external view returns (bool) {
        return keccak256(abi.encodePacked(_attribute)) == _attributeHash;
    }

    function getHistoryLength() external view returns (uint256) {
        return history.length;
    }

    /**
     * @notice Paginated history fetch (gas-safe)
     */
    function getHistory(uint256 offset, uint256 limit)
        external
        view
        returns (HistoryEntry[] memory)
    {
        uint256 end = offset + limit;
        if (end > history.length) end = history.length;

        HistoryEntry[] memory page = new HistoryEntry[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            page[i - offset] = history[i];
        }
        return page;
    }

    // ============================================================
    // 🔹 WRITE FUNCTIONS
    // ============================================================

    function setAttribute(string memory newValue)
        external
        onlyAdminOrOwner
        whenNotPaused
        whenNotLocked
        rateLimited
    {
        if (bytes(newValue).length == 0) revert EmptyString();

        string memory oldValue = _attribute;
        _setAttribute(newValue);

        history.push(
            HistoryEntry(
                newValue,
                _attributeHash,
                block.timestamp,
                msg.sender
            )
        );

        emit AttributeUpdated(msg.sender, oldValue, newValue, block.timestamp);
    }

    // ============================================================
    // 🔹 PAUSE & LOCK CONTROL
    // ============================================================

    function pause() external onlyOwner {
        paused = true;
        emit ContractPaused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit ContractUnpaused(msg.sender);
    }

    function lockAttribute(uint256 duration) external onlyOwner {
        lockUntil = block.timestamp + duration;
        emit AttributeLockedEvent(lockUntil);
    }

    function unlockAttribute() external onlyOwner {
        lockUntil = 0;
        emit AttributeUnlockedEvent();
    }

    // ============================================================
    // 🔹 ROLE MANAGEMENT
    // ============================================================

    function addAdmin(address admin) external onlyOwner {
        if (admin == address(0)) revert InvalidAddress();
        admins[admin] = true;
        emit AdminAdded(admin);
    }

    function removeAdmin(address admin) external onlyOwner {
        admins[admin] = false;
        emit AdminRemoved(admin);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidAddress();
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    // ============================================================
    // 🔹 FALLBACKS
    // ============================================================

    receive() external payable {
        // ETH accepted intentionally (future extensibility)
    }

    fallback() external payable {
        // Safe fallback
    }
}
