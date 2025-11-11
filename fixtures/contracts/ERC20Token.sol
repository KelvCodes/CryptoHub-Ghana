
    // ===========================================
    /

    /// @notice Unpauses token transfers and minting (onlyOwner).
    function unpause() external onlyOwner {
        _unpause();
        emit TokenUnpaused(msg.sender);
    }

    /// @dev Overrides ERC20 hook to enforce pause logic.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);
        require(!paused(), "Token transfers are paused");
    }

    // ===========================================
    // HELPER FUNCTIONS
    // ===========================================

    /// @notice Returns the token's total supply formatted in full units (not wei).
    function getTotalSupply() external view returns (uint256) {
        return totalSupply() / 10 ** decimals();
    }

    /// @notice Returns the caller’s balance in full token units.
    function getMyBalance() external view returns (uint256) {
        return balanceOf(msg.sender) / 10 ** decimals();
    }
}

