

        if (shouldFail) {
            failReason = "Manual deployment failure triggered.";
            emit DeploymentAttempt(msg.sender, failReason, false, msg.value);
            revert DeploymentFailed("Deployment reverted intentionally.");
        }

        deployedSuccessfully = true;
        failReason = "Deployment successful.";
        deploymentTimestamp = block.timestamp;

        emit DeploymentAttempt(msg.sender, failReason, true, msg.value);
    }

    // ===========================================
    // 🔹 FALLBACK & RECEIVE
    // ===========================================

    receive() external payable {
        emit EtherReceived(msg.sender, msg.value);
    }

    fallback() external payable {
        emit FallbackCalled(msg.sender, msg.value, msg.data);
    }

    // ===========================================
    // 🔹 PUBLIC & EXTERNAL FUNCTIONS
    // ===========================================

    /// @notice Returns summary of deployment state.
    function getDeploymentSummary()
        public
        view
        returns (address _deployer, bool _status, string memory _reason, uint256 _timestamp)
    {
        return (deployer, deployedSuccessfully, failReason, deploymentTimestamp);
    }

    /**
     * @notice Example of using revert() intentionally.
     */
    function forceRevert() public pure {
        revert DeploymentFailed("Manual function revert triggered.");
    }

    /**
     * @notice Example of using require() validation.
     */
    function checkMinimumValue(uint256 number) public {
        require(number >= 100, "Provided number must be at least 100.");
        emit ValueCheckPassed(number);
    }

    /**
     * @notice Example of assert() usage (rare & must be safe).
     */
    function assertDeployer() public view {
        // SAFE: deployer is NEVER expected to be address(0)
        assert(deployer != address(0));
    }

    // ===========================================
    // 🔹 OWNER-ONLY FUNCTIONS (ACCESS CONTROL)
    // ===========================================

    modifier onlyDeployer() {
        if (msg.sender != deployer) {
            revert UnauthorizedAccess(msg.sender);
        }
        _;
    }

    /**
     * @notice Allows deployer to withdraw all Ether from the contract.
     */
    function withdraw() public onlyDeployer {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH available to withdraw.");

        payable(deployer).transfer(balance);
        emit Withdrawn(deployer, balance);
    }

    /**
     * @notice Example restricted function for deployer-only errors.
     */
    function restrictedAction() public onlyDeployer {
        // Just a demonstration
        failReason = "Restricted action executed successfully.";
    }

    // ===========================================
    // 🔹 UTILITY VIEW FUNCTIONS
    // ===========================================

    /// @notice Returns contract balance.
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

