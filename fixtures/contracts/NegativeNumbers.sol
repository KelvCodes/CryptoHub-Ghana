ns (int256) {
====================================
    // 🔹 ARITHMETIC OPERATIONS
    // =============================================================

    function execute(Operation op, int256 value)
        external
        onlyOwner
        whenNotPaused
    {
        int256 result;

        if (op == Operation.ADD) {
            result = _storedNumber + value;
        } 
        else if (op == Operation.SUBTRACT) {
            result = _storedNumber - value;
        } 
        else if (op == Operation.MULTIPLY) {
            if (value == 0) revert InvalidValue("Multiply by zero");
            result = _storedNumber * value;
        } 
        else if (op == Operation.DIVIDE) {
            if (value == 0) revert InvalidValue("Divide by zero");
            result = _storedNumber / value;
        }

        _updateNumber(result);
        emit ArithmeticExecuted(msg.sender, op, value, result);
    }

    // =============================================================
    // 🔹 BATCH OPERATIONS
    // =============================================================

    function batchExecute(Operation[] calldata ops, int256[] calldata values)
        external
        onlyOwner
        whenNotPaused
    {
        if (ops.length != values.length) {
            revert InvalidValue("Mismatched inputs");
        }

        for (uint256 i = 0; i < ops.length; i++) {
            execute(ops[i], values[i]);
        }
    }

    // =============================================================
    // 🔹 PAUSE CONTROL
    // =============================================================

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    // =============================================================
    // 🔹 OWNERSHIP
    // =============================================================

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) {
            revert InvalidValue("Zero address");
        }

        address oldOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

