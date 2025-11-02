wner = payable(0x0);

    /// @notice Constructor sets the owner to a default zero address (can be customized)
    constructor() {}

    /// @notice Attempts to transfer the contract balance to the owner if caller is authorized
    /// @dev Reverts with a custom `Unauthorized` error if the caller is not the owner
    function unauthorize() public {
        // Check if the function caller is NOT the owner
        if (msg.sender != owner) revert Unauthorized();

        // If authorized, transfer the contract's entire balance to the owner
        owner.transfer(address(this).balance);
    }

    /// @notice Dummy function to demonstrate the use of a custom error with a string
    /// @dev This always reverts using a custom error `CustomError`
    function badRequire() public {
        // This condition is always true (1 < 2), so the revert always triggers
        if (1 < 2) revert CustomError("reverted using custom Error");

        // This line is never reached due to the unconditional revert above
        owner.transfer(address(this).balance);
    }
}

