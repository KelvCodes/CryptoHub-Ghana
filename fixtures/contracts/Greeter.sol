= keccak256(bytes(currentGreeting)),
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

