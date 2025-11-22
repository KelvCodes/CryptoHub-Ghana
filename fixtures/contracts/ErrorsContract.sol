
    /// @notice Sets dwner);
    }ance);
    }
t in wei to withdraw
    function withd
        (boolount);
    }

    /// @notice Update contract ownership
    /// @param newOwner New owner address
    function updateOwner(address payable newOwner) external onlyOwner {
        if (newOwner == address(0)) revert CustomError("Cannot set zero address as owner");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Pause contract functions in emergencies
    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    /// @notice Unpause contract
    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    // =============================
    // ======== USER FUNCTIONS =====
    // =============================

    /// @notice Deposit Ether into the contract
    /// @dev Minimum deposit of 0.01 Ether
    function deposit() external payable whenNotPaused {
        if (msg.value < 0.01 ether) revert CustomError("Minimum deposit is 0.01 ETH");
        deposits[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    // =============================
    // ======== FALLBACK / RECEIVE ==
    // =============================

    receive() external payable {
        deposits[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    fallback() external payable {
        deposits[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    // =============================
    // ======== HELPER FUNCTIONS ===
    // =============================

    /// @notice Get contract balance
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Get a user's total deposits
    /// @param user Address to check deposits for
    function getUserDeposits(address user) external view returns (uint256) {
        return deposits[user];
    }

    /// @notice Demonstrates custom error
    function badRequire() external pure {
        if (1 < 2) revert CustomError("Reverted using custom error");
    }
}

