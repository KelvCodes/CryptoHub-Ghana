\
///////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized(msg.sender);
        _;
    }

    modifier onlyEditor() {
        if (!editors[msg.sender] && msg.sender != owner)
            revert Unauthorized(msg.sender);
        _;
    }

    modifier whenReadable() {
        if (pauseMode == PauseMode.FullyPaused)
            revert ContractPaused();
        _;
    }

    modifier whenWritable() {
        if (pauseMode != PauseMode.Unpaused)
            revert WritePaused();
        _;
    }

    modifier rateLimited() {
        uint256 last = lastActionAt[msg.sender];
        if (block.timestamp < last + MIN_UPDATE_INTERVAL)
            revert RateLimited(last + MIN_UPDATE_INTERVAL);
        _;
        lastActionAt[msg.sender] = block.timestamp;
    }

    modifier onlyEmergency() {
        if (!emergencyMode) revert EmergencyOnly();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory initialValue) {
        if (bytes(initialValue).length == 0) revert EmptyString();

        owner = msg.sender;
        _currentString = initialValue;
        pauseMode = PauseMode.Unpaused;

        snapshots.push(
            UpdateSnapshot({
                value: initialValue,
                updater: msg.sender,
                timestamp: block.timestamp,
                valueHash: keccak256(bytes(initialValue))
            })
        );

        updateTimestamps[0] = block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                            READ FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function currentString() external view whenReadable returns (string memory) {
        return _currentString;
    }

    function currentHash() external view returns (bytes32) {
        return keccak256(bytes(_currentString));
    }

    function snapshotCount() external view returns (uint256) {
        return snapshots.length;
    }

    function getSnapshot(uint256 index)
        external
        view
        returns (UpdateSnapshot memory)
    {
        return snapshots[index];
    }

    function editorActivity(address editor)
        external
        view
        returns (EditorStats memory)
    {
        return editorStats[editor];
    }

    function lastUpdatedAt() external view returns (uint256) {
        return updateTimestamps[updateCount];
    }

    /*//////////////////////////////////////////////////////////////
                            WRITE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function updateString(string calldata newValue)
        external
        onlyEditor
        whenWritable
        rateLimited
    {
        if (bytes(newValue).length == 0) revert EmptyString();

        string memory old = _currentString;
        _currentString = newValue;
        updateCount++;

        snapshots.push(
            UpdateSnapshot({
                value: newValue,
                updater: msg.sender,
                timestamp: block.timestamp,
                valueHash: keccak256(bytes(newValue))
            })
        );

        updateTimestamps[updateCount] = block.timestamp;

        editorStats[msg.sender].updatesMade++;
        editorStats[msg.sender].lastUpdateAt = block.timestamp;

        emit StringUpdated(
            msg.sender,
            old,
            newValue,
            updateCount,
            block.timestamp
        );
    }

    function restorePrevious()
        external
        onlyOwner
        whenWritable
    {
        if (snapshots.length < 2) revert NoHistory();

        UpdateSnapshot memory prev = snapshots[snapshots.length - 2];
        _currentString = prev.value;
        updateCount++;

        snapshots.push(
            UpdateSnapshot({
                value: prev.value,
                updater: msg.sender,
                timestamp: block.timestamp,
                valueHash: prev.valueHash
            })
        );

        updateTimestamps[updateCount] = block.timestamp;

        emit StringUpdated(
            msg.sender,
            "",
            prev.value,
            updateCount,
            block.timestamp
        );
    }

    /*//////////////////////////////////////////////////////////////
                        OWNER / ROLE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function addEditor(address editor) external onlyOwner {
        if (editor == address(0)) revert InvalidAddress();
        if (editors[editor]) revert AlreadyEditor(editor);

        editors[editor] = true;
        emit EditorAdded(editor);
    }

    function removeEditor(address editor) external onlyOwner {
        editors[editor] = false;
        emit EditorRemoved(editor);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    /*//////////////////////////////////////////////////////////////
                            PAUSE CONTROLS
    //////////////////////////////////////////////////////////////*/

    function setPauseMode(PauseMode mode) external onlyOwner {
        pauseMode = mode;
        emit PauseModeChanged(mode);
    }

    /*//////////////////////////////////////////////////////////////
                        EMERGENCY MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function activateEmergency(address recovery)
        external
        onlyOwner
    {
        if (recovery == address(0)) revert InvalidAddress();
        emergencyMode = true;
        recoveryAddress = recovery;
        emit EmergencyModeActivated(recovery);
    }

    function emergencyRestore(string calldata value)
        external
        onlyEmergency
    {
        if (msg.sender != recoveryAddress)
            revert Unauthorized(msg.sender);

        _currentString = value;
        emit EmergencyRecovered(value);
    }

    /*//////////////////////////////////////////////////////////////
                        MAINTENANCE UTILITIES
    //////////////////////////////////////////////////////////////*/

    function clearHistory() external onlyOwner {
        delete snapshots;
        emit HistoryCleared(updateCount);
    }

    function renounceEmergency() external onlyOwner {
        emergencyMode = false;
        recoveryAddress = address(0);
    }
}
