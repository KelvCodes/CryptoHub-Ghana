// SPDX-License-Identifier: GNU
pragma solidity ^0.8.20;

/**
 * ============================================================
 * @title UltimateGreeterPro
 * @author Kelvin
 * @notice A next-generation greeting management smart contract
 *
 * FEATURES
 * ------------------------------------------------------------
 * 1. Role-Based Access Control (Owner + Admins)
 * 2. Greeting history with metadata (timestamp, sender)
 * 3. Greeting analytics (pinned, removed, active)
 * 4. Pause & resume contract operations
 * 5. Contract versioning
 * 6. Extensive event logging
 * 7. Defensive programming & modular design
 *
 * USE CASES
 * ------------------------------------------------------------
 * - Learning advanced Solidity architecture
 * - Demo contract for dApps
 * - Base template for content-management systems
 *
 * VERSION: v2.0.0
 * ============================================================
 */
contract UltimateGreeterPro {

    // ============================================================
    // ========================== STRUCTS =========================
    // ============================================================

    /**
     * @notice Stores full metadata for each greeting
     */
    struct GreetingRecord {
        string message;          // Greeting text
        address setBy;           // Who set it
        uint256 timestamp;       // When it was set
        bool pinned;             // Highlighted greeting
        bool removed;            // Soft-deleted greeting
    }

    // ============================================================
    // ===================== STATE VARIABLES ======================
    // ============================================================

    /// @notice Counter for demonstration & analytics
    uint256 private counter;

    /// @notice Current active greeting
    string private currentGreeting;

    /// @notice Contract owner
    address public owner;

    /// @notice Timestamp of last greeting update
    uint256 public lastUpdated;

    /// @notice Contract semantic version
    string public version = "v2.0.0";

    /// @notice Pause flag for emergency stops
    bool public paused;

    /// @notice Admin role mapping
    mapping(address => bool) public admins;

    /// @notice Storage for all greetings ever added
    GreetingRecord[] private greetingRecords;

    // ============================================================
    // =========================== EVENTS =========================
    // ============================================================

    event GreetingChanging(string from, string to, address changedBy);
    event GreetingChanged(string newGreeting, address indexed changedBy, uint256 timestamp);

    event CounterIncremented(uint256 newValue, address indexed incrementedBy);
    event CounterReset(address indexed resetBy, uint256 timestamp);

    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);

    event ContractPaused(address indexed by);
    event ContractUnpaused(address indexed by);

    event GreetingPinned(uint256 indexed index, string message, address pinnedBy);
    event GreetingUnpinned(uint256 indexed index, address unpinnedBy);

    event GreetingRemoved(uint256 indexed index, address removedBy);
    event GreetingRestored(uint256 indexed index, address restoredBy);

    // ============================================================
    // ========================== MODIFIERS =======================
    // ============================================================

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner allowed");
        _;
    }

    modifier onlyAdmin() {
        require(
            admins[msg.sender] || msg.sender == owner,
            "Only admin or owner allowed"
        );
        _;
    }

    modifier notPaused() {
        require(!paused, "Contract paused");
        _;
    }

    modifier validIndex(uint256 index) {
        require(index < greetingRecords.length, "Invalid index");
        _;
    }

    modifier notSameGreeting(string memory _newGreeting) {
        require(
            keccak256(bytes(_newGreeting)) != keccak256(bytes(currentGreeting)),
            "Greeting unchanged"
        );
        _;
    }

    // ============================================================
    // ========================= CONSTRUCTOR ======================
    // ============================================================

    /**
     * @notice Initializes contract with first greeting
     */
    constructor(string memory _initialGreeting) {
        owner = msg.sender;
        currentGreeting = _initialGreeting;
        lastUpdated = block.timestamp;
        counter = 0;

        greetingRecords.push(
            GreetingRecord({
                message: _initialGreeting,
                setBy: msg.sender,
                timestamp: block.timestamp,
                pinned: false,
                removed: false
            })
        );
    }

    // ============================================================
    // ======================== VIEW FUNCTIONS ====================
    // ============================================================

    function greet() public view returns (string memory) {
        return currentGreeting;
    }

    function getCounter() public view returns (uint256) {
        return counter;
    }

    function getGreetingCount() public view returns (uint256) {
        return greetingRecords.length;
    }

    function getGreetingRecord(uint256 index)
        public
        view
        validIndex(index)
        returns (GreetingRecord memory)
    {
        return greetingRecords[index];
    }

    function getAllGreetings()
        public
        view
        returns (GreetingRecord[] memory)
    {
        return greetingRecords;
    }

    function getPinnedGreetings()
        public
        view
        returns (GreetingRecord[] memory)
    {
        uint256 count;
        for (uint256 i = 0; i < greetingRecords.length; i++) {
            if (greetingRecords[i].pinned && !greetingRecords[i].removed) {
                count++;
            }
        }

        GreetingRecord[] memory pinned = new GreetingRecord[](count);
        uint256 idx;

        for (uint256 i = 0; i < greetingRecords.length; i++) {
            if (greetingRecords[i].pinned && !greetingRecords[i].removed) {
                pinned[idx++] = greetingRecords[i];
            }
        }

        return pinned;
    }

    function getActiveGreetings()
        public
        view
        returns (GreetingRecord[] memory)
    {
        uint256 count;
        for (uint256 i = 0; i < greetingRecords.length; i++) {
            if (!greetingRecords[i].removed) count++;
        }

        GreetingRecord[] memory active = new GreetingRecord[](count);
        uint256 idx;

        for (uint256 i = 0; i < greetingRecords.length; i++) {
            if (!greetingRecords[i].removed) {
                active[idx++] = greetingRecords[i];
            }
        }

        return active;
    }

    // ============================================================
    // =================== STATE-CHANGING LOGIC ===================
    // ============================================================

    function setGreeting(string memory _newGreeting)
        public
        onlyAdmin
        notPaused
        notSameGreeting(_newGreeting)
        returns (bool success, string memory greeting)
    {
        emit GreetingChanging(currentGreeting, _newGreeting, msg.sender);

        currentGreeting = _newGreeting;
        lastUpdated = block.timestamp;

        greetingRecords.push(
            GreetingRecord({
                message: _newGreeting,
                setBy: msg.sender,
                timestamp: block.timestamp,
                pinned: false,
                removed: false
            })
        );

        emit GreetingChanged(_newGreeting, msg.sender, block.timestamp);
        return (true, _newGreeting);
    }

    function incrementCounter() public notPaused {
        counter++;
        emit CounterIncremented(counter, msg.sender);
    }

    function resetCounter() public onlyAdmin notPaused {
        counter = 0;
        emit CounterReset(msg.sender, block.timestamp);
    }

    // ============================================================
    // ==================== ADMIN & OWNER LOGIC ===================
    // ============================================================

    function addAdmin(address newAdmin) public onlyOwner {
        require(newAdmin != address(0), "Zero address");
        admins[newAdmin] = true;
        emit AdminAdded(newAdmin);
    }

    function removeAdmin(address adminAddr) public onlyOwner {
        require(admins[adminAddr], "Not admin");
        admins[adminAddr] = false;
        emit AdminRemoved(adminAddr);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Invalid owner");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function pauseContract() public onlyOwner {
        paused = true;
        emit ContractPaused(msg.sender);
    }

    function unpauseContract() public onlyOwner {
        paused = false;
        emit ContractUnpaused(msg.sender);
    }

    // ============================================================
    // =================== GREETING MANAGEMENT ====================
    // ============================================================

    function pinGreeting(uint256 index)
        public
        onlyAdmin
        notPaused
        validIndex(index)
    {
        greetingRecords[index].pinned = true;
        emit GreetingPinned(index, greetingRecords[index].message, msg.sender);
    }

    function unpinGreeting(uint256 index)
        public
        onlyAdmin
        notPaused
        validIndex(index)
    {
        greetingRecords[index].pinned = false;
        emit GreetingUnpinned(index, msg.sender);
    }

    function removeGreeting(uint256 index)
        public
        onlyAdmin
        notPaused
        validIndex(index)
    {
        greetingRecords[index].removed = true;
        emit GreetingRemoved(index, msg.sender);
    }

    function restoreGreeting(uint256 index)
        public
        onlyAdmin
        notPaused
        validIndex(index)
    {
        greetingRecords[index].removed = false;
        emit GreetingRestored(index, msg.sender);
    }

    // ============================================================
    // ========================= UTILITIES ========================
    // ============================================================

    function updateVersion(string memory _newVersion) public onlyOwner {
        version = _newVersion;
    }

    function getVersion() public view returns (string memory) {
        return version;
    }
}

