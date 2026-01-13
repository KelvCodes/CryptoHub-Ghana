
pragma solidity ^0.8.20;

/**
 * @title UltimateGreeterPro
 * @notice A next-generation greeting contract with advanced management, analytics,
 * and modular control features. Includes:
 * - Role-based access control (Owner + Admins)
 * - Greeting history with timestamps and sender tracking
 * - Greeting analytics, pinning, and removal system
 * - Contract versioning, pause mechanism, and event logging
 */
contract UltimateGreeterPro {
    // ================================
    //  STRUCTS
    // ================================
    struct GreetingRecord {
        string message;
        address setBy;
        uint256 timestamp;
        bool pinned;
        bool removed;
    }

    // ================================
    // STATE VARIABLES
    // ================================
    uint256 private counter;
    string private currentGreeting;
    address public owner;
    uint256 public lastUpdated;
    string public version = "v2.0.0";

    bool public paused;

    // Mappings for roles and greetings
    mapping(address => bool) public admins;
    GreetingRecord[] private greetingRecords;

    // ================================
    //  EVENTS
    // ================================
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

    // ================================
    //  MODIFIERS
    // ================================
    modifier onlyOwner() {
        require(msg.sender == owner, "Access denied: only owner");
        _;
    }

    modifier onlyAdmin() {
        require(admins[msg.sender] || msg.sender == owner, "Access denied: only admin or owner");
        _;
    }

    modifier notPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier notSameGreeting(string memory _newGreeting) {
        require(
            keccak256(bytes(_newGreeting)) != keccak256(bytes(currentGreeting)),
            "New greeting must differ from current"
        );
        _;
    }

    // ================================
    //  CONSTRUCTOR
    // ================================
    constructor(string memory _initialGreeting) {
        owner = msg.sender;
        currentGreeting = _initialGreeting;
        counter = 0;
        lastUpdated = block.timestamp;
        greetingRecords.push(GreetingRecord(_initialGreeting, msg.sender, block.timestamp, false, false));
    }

    // ================================
    //  VIEW FUNCTIONS
    // ================================
    function greet() public view returns (string memory) {
        return currentGreeting;
    }

    function getCounter() public view returns (uint256) {
        return counter;
    }

    function getGreetingCount() public view returns (uint256) {
        return greetingRecords.length;
    }

    function getGreetingRecord(uint256 index) public view returns (GreetingRecord memory) {
        require(index < greetingRecords.length, "Invalid index");
        return greetingRecords[index];
    }

    function getAllGreetings() public view returns (GreetingRecord[] memory) {
        return greetingRecords;
    }

    function getPinnedGreetings() public view returns (GreetingRecord[] memory) {
        uint256 total = greetingRecords.length;
        uint256 count;
        for (uint256 i = 0; i < total; i++) {
            if (greetingRecords[i].pinned) count++;
        }
        GreetingRecord[] memory pinned = new GreetingRecord[](count);
        uint256 idx;
        for (uint256 i = 0; i < total; i++) {
            if (greetingRecords[i].pinned) {
                pinned[idx] = greetingRecords[i];
                idx++;
            }
        }
        return pinned;
    }

    // ================================
    //  STATE-CHANGING FUNCTIONS
    // ================================
    function setGreeting(string memory _newGreeting)
        public
        onlyAdmin
        notPaused
        notSameGreeting(_newGreeting)
        returns (bool, string memory)
    {
        emit GreetingChanging(currentGreeting, _newGreeting, msg.sender);

        currentGreeting = _newGreeting;
        lastUpdated = block.timestamp;

        greetingRecords.push(GreetingRecord(_newGreeting, msg.sender, block.timestamp, false, false));

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

    // ================================
    //  ADMIN & OWNER FUNCTIONS
    // ================================
    function addAdmin(address newAdmin) public onlyOwner {
        require(newAdmin != address(0), "Invalid admin");
        admins[newAdmin] = true;
        emit AdminAdded(newAdmin);
    }

    function removeAdmin(address adminAddr) public onlyOwner {
        require(admins[adminAddr], "Address is not admin");
        admins[adminAddr] = false;
        emit AdminRemoved(adminAddr);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
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

    // ================================
    //  GREETING MANAGEMENT
    // ================================
    function pinGreeting(uint256 index) public onlyAdmin notPaused {
        require(index < greetingRecords.length, "Invalid index");
        greetingRecords[index].pinned = true;
        emit GreetingPinned(index, greetingRecords[index].message, msg.sender);
    }

    function unpinGreeting(uint256 index) public onlyAdmin notPaused {
        require(index < greetingRecords.length, "Invalid index");
        greetingRecords[index].pinned = false;
        emit GreetingUnpinned(index, msg.sender);
    }

    function removeGreeting(uint256 index) public onlyAdmin notPaused {
        require(index < greetingRecords.length, "Invalid index");
        greetingRecords[index].removed = true;
        emit GreetingRemoved(index, msg.sender);
    }

    function restoreGreeting(uint256 index) public onlyAdmin notPaused {
        require(index < greetingRecords.length, "Invalid index");
        greetingRecords[index].removed = false;
        emit GreetingRestored(index, msg.sender);
    }

    // ================================
    //  UTILITIES
    // ================================
    function getActiveGreetings() public view returns (GreetingRecord[] memory) {
        uint256 total = greetingRecords.length;
        uint256 count;
        for (uint256 i = 0; i < total; i++) {
            if (!greetingRecords[i].removed) count++;
        }
        GreetingRecord[] memory active = new GreetingRecord[](count);
        uint256 idx;
        for (uint256 i = 0; i < total; i++) {
            if (!greetingRecords[i].removed) {
                active[idx] = greetingRecords[i];
                idx++;
            }
        }
        return active;
    }

    function getVersion() public view returns (string memory) {
        return version;
    }

    function updateVersion(string memory _newVersion) public onlyOwner {
        version = _newVersion;
    }
}

