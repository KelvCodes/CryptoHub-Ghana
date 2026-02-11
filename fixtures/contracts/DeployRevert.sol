
============================================
    // 🔹 CUSTOM ERRORS
    // =============================================================

    error DeploymentFailed(string reason);
    error InvalidDeployer(address sender);
    error InsufficientDeploymentFunds(uint256 sent, uint256 required);
    error UnauthorizedAccess(address caller);
    error ContractPaused();
    error ContractInEmergency();
    error ReentrancyDetected();
    error ZeroAmount();
    error WithdrawTooLarge(uint256 requested);
    error WithdrawCooldownActive(uint256 remaining);
    error ExternalCallFailed();

    // =============================================================
    // 🔹 EVENTS
    // =============================================================

    event DeploymentAttempt(
        address indexed deployer,
        bool success,
        uint256 valueSent,
        string message
    );

    event EtherReceived(address indexed sender, uint256 amount);
    event EtherWithdrawn(address indexed to, uint256 amount);
    event ContractPausedEvent(address indexed caller);
    event ContractResumedEvent(address indexed caller);
    event EmergencyModeActivated(address indexed caller);
    event EmergencyModeDisabled(address indexed caller);
    event RoleGranted(address indexed user, Role role);
    event ExternalCallResult(bool success, bytes data);

    // =============================================================
    // 🔹 MODIFIERS
    // =============================================================

    modifier onlyDeployer() {
        if (msg.sender != deployer) revert UnauthorizedAccess(msg.sender);
        _;
    }

    modifier onlyAdmin() {
        if (roles[msg.sender] != Role.ADMIN) revert UnauthorizedAccess(msg.sender);
        _;
    }

    modifier whenActive() {
        if (deploymentState != DeploymentState.Active) revert ContractPaused();
        _;
    }

    modifier notEmergency() {
        if (deploymentState == DeploymentState.Emergency)
            revert ContractInEmergency();
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

    constructor(bool shouldFail) payable {
        if (msg.sender == address(0)) revert InvalidDeployer(msg.sender);
        if (msg.value < MIN_DEPLOY_ETH)
            revert InsufficientDeploymentFunds(msg.value, MIN_DEPLOY_ETH);

        deployer = msg.sender;
        roles[msg.sender] = Role.DEPLOYER;
        roles[msg.sender] = Role.ADMIN;

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
    // 🔹 CORE DEMONSTRATIONS
    // =============================================================

    function checkValue(uint256 value) external pure {
        require(value >= 100, "Value must be >= 100");
    }

    function assertInvariant() external view {
        assert(deployer != address(0));
    }

    function forceRevert() external pure {
        revert DeploymentFailed("Manual revert triggered");
    }

    // =============================================================
    // 🔹 PAUSE & EMERGENCY CONTROL
    // =============================================================

    function pause() external onlyAdmin {
        deploymentState = DeploymentState.Paused;
        emit ContractPausedEvent(msg.sender);
    }

    function resume() external onlyAdmin {
        deploymentState = DeploymentState.Active;
        emit ContractResumedEvent(msg.sender);
    }

    function activateEmergency() external onlyAdmin {
        deploymentState = DeploymentState.Emergency;
        emit EmergencyModeActivated(msg.sender);
    }

    function disableEmergency() external onlyAdmin {
        deploymentState = DeploymentState.Active;
        emit EmergencyModeDisabled(msg.sender);
    }

    // =============================================================
    // 🔹 ROLE MANAGEMENT
    // =============================================================

    function grantAdmin(address user) external onlyDeployer {
        roles[user] = Role.ADMIN;
        emit RoleGranted(user, Role.ADMIN);
    }

    // =============================================================
    // 🔹 WITHDRAWAL LOGIC (PULL PAYMENTS)
    // =============================================================

    function requestWithdraw(uint256 amount)
        external
        onlyDeployer
        whenActive
        notEmergency
    {
        if (amount == 0) revert ZeroAmount();
        if (amount > MAX_WITHDRAW_PER_TX)
            revert WithdrawTooLarge(amount);

        pendingWithdrawals[msg.sender] += amount;
    }

    function withdraw() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        if (amount == 0) revert ZeroAmount();

        uint256 lastTime = lastWithdrawTime[msg.sender];
        if (block.timestamp < lastTime + WITHDRAW_COOLDOWN)
            revert WithdrawCooldownActive(
                (lastTime + WITHDRAW_COOLDOWN) - block.timestamp
            );

        pendingWithdrawals[msg.sender] = 0;
        lastWithdrawTime[msg.sender] = block.timestamp;
        totalEtherWithdrawn += amount;

        payable(msg.sender).transfer(amount);
        emit EtherWithdrawn(msg.sender, amount);
    }

    // =============================================================
    // 🔹 TRY / CATCH EXTERNAL CALL DEMO
    // =============================================================

    function callExternal(address target, bytes calldata data)
        external
        onlyAdmin
        returns (bool, bytes memory)
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

    function getRole(address user) external view returns (Role) {
        return roles[user];
    }

    function getDeploymentSummary()
        external
        view
        returns (
            address _deployer,
            DeploymentState _state,
            uint256 _timestamp,
            uint256 _received,
            uint256 _withdrawn,
            string memory _status
        )
    {
        return (
            deployer,
            deploymentState,
            deploymentTimestamp,
            totalEtherReceived,
            totalEtherWithdrawn,
            lastStatusMessage
        );
    }
}

