 always reverts using a custom error `CustomError`
re() public {
        // This condition is always true (1 < 2), so the revert always triggers
        if (1 < 2) revert CustomError("reverted using custom Error");

        // This line is never reached due to the unconditional revert above
        owner.transfer(address(this).balance);
    }
}

