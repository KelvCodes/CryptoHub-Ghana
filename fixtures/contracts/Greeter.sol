
     * @notice Increment the counter by 1.
     * Emits an event after incrementing.
     */
        counter = 0;
        emit CounterReset(block.timestamp);
    }

    /**
     * @notice Transfer contract ownership to a new address.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        owner = newOwner;
    }
}

