
     * @dev If `shouldFail` is true, the constructor reverts using a custom error.
     */
    constructor(bool shouldFail) payable {
        deployer = msg.sender;

        // Example conditional logic before deploying
        if (msg.sender == address(0)) {
            revert InvalidDeployer(msg.sender);
        }

        // Simulate a failure based on the provided flag
        if (shouldFail) {
            failReason = "Manual deployment failure triggered.";
            emit DeploymentAttempt(msg.sender, failReason, false);
            revert DeploymentFailed("Deployment reverted intentionally.");
        }

        // If no failure condition is met
        deployedSuccessfully = true;
        failReason = "Deployment successful.";
        emit DeploymentAttempt(msg.sender, failReason, true);
    }

    // ===========================================
    // 🔹 FALLBACK AND RECEIVE FUNCTIONS
    // ===========================================

    /// @notice Triggered when contract receives Ether without calldata.
    receive() external payable {
        emit EtherReceived(msg.sender, msg.value);
    }

    /// @notice Triggered when calldata doesn’t match any function signature.
    fallback() external payable {
        emit FallbackCalled(msg.sender, msg.value);
    }

    // ===========================================
    // 🔹 PUBLIC FUNCTIONS
    // ===========================================

    /**
     * @notice Returns a simple summary of the deployment state.
     * @return _deployer The address of the deployer.
     * @return _status Whether deployment was successful.
     * @return _reason Reason message.
     */
    function getDeploymentSummary()
        public
        view
        returns (address _deployer, bool _status, string memory _reason)
    {
        return (deployer, deployedSuccessfully, failReason);
    }

    /**
     * @notice Example function that reverts manually.
     */
    function forceRevert() public pure {
        revert DeploymentFailed("Manual function revert triggered.");
    }
}

