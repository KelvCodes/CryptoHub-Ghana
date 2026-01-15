
         memory currentString, uint256 totalUpdates, address currentOwner, bool isPaused)
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

