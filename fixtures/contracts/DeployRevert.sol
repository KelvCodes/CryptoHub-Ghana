
    event ExternalCallResult(bool success, bytes data);

    // =============================================================
    // 🔹 MODIFIERS
    // =============================================================

    modifier onlyDeployer() {
        if (msg.sender != deployer) {
            revert UnauthorizedAccess(msg.sender);
        }
        _;
    }

    modifier whenActive() {
        if (deploymentState != DeploymentState.Active) {
            revert ContractPaused();
        }
        _;
    }

    modifier nonReentrant() {
        if (locked) revert ReentrancyDetected();
        locked = true;
        _;
        locked = false;
    }

    // =============================================================
    // 🔹 CONSTRUCTOR
    // =============================================================

    /**
     * @notice Validates deployment and optionally forces failure
     * @param shouldFail Forces constructor to revert if true
     */
    constructor(bool shouldFail) payable {
        if (msg.sender == address(0)) {
            revert InvalidDeployer(msg.sender);
        }

        if (msg.value < MIN_DEPLOY_ETH) {
            revert InsufficientDeploymentFunds(msg.value, MIN_DEPLOY_ETH);
        }

        deployer = msg.sender;
        totalEtherReceived += msg.value;

        if (shouldFail) {
            deploymentState = DeploymentState.Failed;
            emit DeploymentAttempt(msg.sender, false, msg.value, "Forced failure");
            revert DeploymentFailed("Constructor intentionally reverted");
        }

        deploymentState = DeploymentState.Active;
        deploymentTimestamp = block.timestamp;
        lastStatusMessage = "Deployment successful";

        emit DeploymentAttempt(msg.sender, true, msg.value, lastStatusMessage);
    }

    // =============================================================
    // 🔹 RECEIVE & FALLBACK
    // =============================================================

    receive() external payable {
        totalEtherReceived += msg.value;
        emit EtherReceived(msg.sender, msg.value);
    }

    fallback() external payable {
        totalEtherReceived += msg.value;
        emit EtherReceived(msg.sender, msg.value);
    }

    // =============================================================
    // 🔹 CORE FUNCTIONS
    // =============================================================

    /**
     * @notice Demonstrates require-based validation
     */
    function checkValue(uint256 value) external pure {
        require(value >= 100, "Value must be >= 100");
    }

    /**
     * @notice Demonstrates assert usage (invariant)
     */
    function assertInvariant() external view {
        // deployer must NEVER be zero
        assert(deployer != address(0));
    }

    /**
     * @notice Force revert example using custom error
     */
    function forceRevert() external pure {
        revert DeploymentFailed("Manual revert triggered");
    }

    // =============================================================
    // 🔹 PAUSE CONTROL
    // =============================================================

    function pause() external onlyDeployer {
        deploymentState = DeploymentState.Paused;
        emit ContractPausedEvent(msg.sender);
    }

    function resume() external onlyDeployer {
        deploymentState = DeploymentState.Active;
        emit ContractResumedEvent(msg.sender);
    }

    // =============================================================
    // 🔹 WITHDRAWAL LOGIC (PULL PAYMENT)
    // =============================================================

    /**
     * @notice Registers a withdrawal request for deployer
     */
    function requestWithdraw(uint256 amount)
        external
        onlyDeployer
        whenActive
    {
        if (amount == 0) revert ZeroAmount();
        if (amount > address(this).balance) revert ZeroAmount();

        pendingWithdrawals[msg.sender] += amount;
    }

    /**
     * @notice Secure ETH withdrawal (pull-based)
     */
    function withdraw() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        if (amount == 0) revert ZeroAmount();

        pendingWithdrawals[msg.sender] = 0;
        payable(msg.sender).transfer(amount);

        emit EtherWithdrawn(msg.sender, amount);
    }

    // =============================================================
    // 🔹 TRY / CATCH EXTERNAL CALL DEMO
    // =============================================================

    /**
     * @notice Demonstrates try/catch with low-level call
     */
    function callExternal(address target, bytes calldata data)
        external
        onlyDeployer
        returns (bool success, bytes memory result)
    {
        try this._externalCall(target, data) returns (bytes memory response) {
            emit ExternalCallResult(true, response);
            return (true, response);
        } catch {
            emit ExternalCallResult(false, "");
            revert ExternalCallFailed();
        }
    }

    function _externalCall(address target, bytes calldata data)
        external
        returns (bytes memory)
    {
        (bool success, bytes memory result) = target.call(data);
        require(success, "Low-level call failed");
        return result;
    }

    // =============================================================
    // 🔹 VIEW FUNCTIONS
    // =============================================================

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getPendingWithdrawal(address user)
        external
        view
        returns (uint256)
    {
        return pendingWithdrawals[user];
    }

    function getDeploymentSummary()
        external
        view
        returns (
            address _deployer,
            DeploymentState _state,
            uint256 _timestamp,
            uint256 _totalReceived,
            string memory _status
        )
    {
        return (
            deployer,
            deploymentState,
            deploymentTimestamp,
            totalEtherReceived,
            lastStatusMessage
        );
    }
}

