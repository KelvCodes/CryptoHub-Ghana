// SPDX-License-Identifier: GNU
pragma solidity ^0.8.13;

/**
 * =============================================================
 *  DeployRevertPro Ultra (Enterprise Edition)
 * =============================================================
 * @author Kelvin
 *
 * @notice
 * This contract demonstrates professional-grade Solidity patterns:
 * - Constructor validation & forced deployment revert
 * - Custom errors (gas optimized)
 * - Require vs Revert vs Assert
 * - Pull payments & reentrancy protection
 * - Pausing & emergency shutdown
 * - Try/Catch & low-level calls
 * - Access control & role separation
 * - ETH accounting & rate limiting
 * - Audit-friendly architecture
 *
 * @dev
 * This contract is intentionally verbose and educational.
 * Designed for interviews, audits, and deep Solidity mastery.
 */

contract DeployRevertProUltra {
    // =============================================================
    // ENUMS - State Management
    // =============================================================
    
    /**
     * @dev Deployment lifecycle states
     * NotDeployed: Initial state before constructor completes
     * Active: Normal operational state
     * Paused: Temporary halt of non-critical functions
     * Emergency: Critical halt for security incidents
     * Failed: Deployment reverted state
     */
    enum DeploymentState {
        NotDeployed,
        Active,
        Paused,
        Emergency,
        Failed
    }

    /**
     * @dev Access control levels
     * NONE: No privileges
     * DEPLOYER: Contract creator - can grant admin roles
     * ADMIN: Can pause, emergency halt, and execute privileged functions
     */
    enum Role {
        NONE,
        DEPLOYER,
        ADMIN
    }

    // =============================================================
    // CONSTANTS - Immutable Configuration
    // =============================================================
    
    // Minimum ETH required for successful deployment (prevents dust deployments)
    uint256 public constant MIN_DEPLOY_ETH = 0.01 ether;
    
    // Maximum withdraw amount per transaction (limits exposure in case of compromise)
    uint256 public constant MAX_WITHDRAW_PER_TX = 5 ether;
    
    // Minimum time between withdrawals (prevents rapid draining)
    uint256 public constant WITHDRAW_COOLDOWN = 1 minutes;

    // =============================================================
    // IMMUTABLES - Permanent References
    // =============================================================
    
    // Deployer address is immutable - cannot be changed after construction
    address public immutable deployer;

    // =============================================================
    // STATE VARIABLES - Contract State
    // =============================================================
    
    DeploymentState public deploymentState;      // Current contract state
    string public lastStatusMessage;             // Last operation status
    uint256 public deploymentTimestamp;          // Block timestamp of successful deployment
    uint256 public totalEtherReceived;           // Lifetime ETH received
    uint256 public totalEtherWithdrawn;          // Lifetime ETH withdrawn

    bool private locked;                        // Reentrancy guard flag

    // =============================================================
    // ROLE MANAGEMENT - Access Control
    // =============================================================
    
    mapping(address => Role) private roles;      // User role assignments

    // =============================================================
    // WITHDRAWAL ACCOUNTING - Pull Payment System
    // =============================================================
    
    mapping(address => uint256) private pendingWithdrawals;  // Accumulated withdrawable amounts
    mapping(address => uint256) private lastWithdrawTime;    // Timestamp of last withdrawal per user

    // =============================================================
    // CUSTOM ERRORS - Gas Optimized Error Handling
    // =============================================================
    
    error DeploymentFailed(string reason);                    // Constructor revert with reason
    error InvalidDeployer(address sender);                   // Zero address deployment attempt
    error InsufficientDeploymentFunds(uint256 sent, uint256 required); // Not enough ETH for deployment
    error UnauthorizedAccess(address caller);                // Permission denied
    error ContractPaused();                                  // Contract is paused
    error ContractInEmergency();                             // Contract in emergency state
    error ReentrancyDetected();                              // Reentrancy attempt blocked
    error ZeroAmount();                                      // Zero value operation
    error WithdrawTooLarge(uint256 requested);              // Exceeds MAX_WITHDRAW_PER_TX
    error WithdrawCooldownActive(uint256 remaining);         // Cooldown period not elapsed
    error ExternalCallFailed();                             // Low-level call failed

    // =============================================================
    // EVENTS - Off-chain Monitoring
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
    // MODIFIERS - Access Control & Guards
    // =============================================================
    
    /**
     * @dev Restricts function to deployer only
     */
    modifier onlyDeployer() {
        if (msg.sender != deployer) revert UnauthorizedAccess(msg.sender);
        _;
    }

    /**
     * @dev Restricts function to admin role only
     */
    modifier onlyAdmin() {
        if (roles[msg.sender] != Role.ADMIN) revert UnauthorizedAccess(msg.sender);
        _;
    }

    /**
     * @dev Ensures contract is in Active state
     */
    modifier whenActive() {
        if (deploymentState != DeploymentState.Active) revert ContractPaused();
        _;
    }

    /**
     * @dev Prevents operations during emergency state
     */
    modifier notEmergency() {
        if (deploymentState == DeploymentState.Emergency)
            revert ContractInEmergency();
        _;
    }

    /**
     * @dev Reentrancy protection using mutex pattern
     */
    modifier nonReentrant() {
        if (locked) revert ReentrancyDetected();
        locked = true;
        _;
        locked = false;
    }

    // =============================================================
    // CONSTRUCTOR - Deployment Phase
    // =============================================================
    
    /**
     * @dev Contract constructor with conditional revert
     * @param shouldFail If true, constructor will revert with custom error
     * 
     * Requirements:
     * - Deployer cannot be zero address
     * - Must send at least MIN_DEPLOY_ETH
     * 
     * State Changes:
     * - Sets immutable deployer address
     * - Grants DEPLOYER and ADMIN roles to deployer
     * - Tracks initial ETH contribution
     * - Optionally reverts with forced failure
     */
    constructor(bool shouldFail) payable {
        // Validate deployer address
        if (msg.sender == address(0)) revert InvalidDeployer(msg.sender);
        
        // Validate minimum deployment funds
        if (msg.value < MIN_DEPLOY_ETH)
            revert InsufficientDeploymentFunds(msg.value, MIN_DEPLOY_ETH);

        // Initialize core state
        deployer = msg.sender;
        roles[msg.sender] = Role.DEPLOYER;
        roles[msg.sender] = Role.ADMIN;

        // Track initial ETH
        totalEtherReceived += msg.value;

        // Conditional revert for demonstration
        if (shouldFail) {
            deploymentState = DeploymentState.Failed;
            emit DeploymentAttempt(msg.sender, false, msg.value, "Forced failure");
            revert DeploymentFailed("Constructor intentionally reverted");
        }

        // Successful deployment
        deploymentState = DeploymentState.Active;
        deploymentTimestamp = block.timestamp;
        lastStatusMessage = "Deployment successful";

        emit DeploymentAttempt(msg.sender, true, msg.value, lastStatusMessage);
    }

    // =============================================================
    // RECEIVE & FALLBACK - ETH Acceptance
    // =============================================================
    
    /**
     * @dev Handles plain ETH transfers
     * Updates total received and emits event
     */
    receive() external payable {
        totalEtherReceived += msg.value;
        emit EtherReceived(msg.sender, msg.value);
    }

    /**
     * @dev Handles calls with calldata and ETH transfers
     * Same behavior as receive() for maximum flexibility
     */
    fallback() external payable {
        totalEtherReceived += msg.value;
        emit EtherReceived(msg.sender, msg.value);
    }

    // =============================================================
    // CORE DEMONSTRATIONS - Error Handling Patterns
    // =============================================================
    
    /**
     * @dev Demonstrates require() pattern with custom message
     * @param value Value to validate against minimum threshold
     */
    function checkValue(uint256 value) external pure {
        require(value >= 100, "Value must be >= 100");
    }

    /**
     * @dev Demonstrates assert() pattern for invariant checking
     * Use for conditions that should never be false
     */
    function assertInvariant() external view {
        assert(deployer != address(0));
    }

    /**
     * @dev Demonstrates revert() with custom error
     */
    function forceRevert() external pure {
        revert DeploymentFailed("Manual revert triggered");
    }

    // =============================================================
    // PAUSE & EMERGENCY CONTROL - Circuit Breaker Pattern
    // =============================================================
    
    /**
     * @dev Temporarily halts non-emergency functions
     * Only callable by admin
     */
    function pause() external onlyAdmin {
        deploymentState = DeploymentState.Paused;
        emit ContractPausedEvent(msg.sender);
    }

    /**
     * @dev Resumes normal operations
     * Only callable by admin
     */
    function resume() external onlyAdmin {
        deploymentState = DeploymentState.Active;
        emit ContractResumedEvent(msg.sender);
    }

    /**
     * @dev Activates full emergency shutdown
     * Only callable by admin
     */
    function activateEmergency() external onlyAdmin {
        deploymentState = DeploymentState.Emergency;
        emit EmergencyModeActivated(msg.sender);
    }

    /**
     * @dev Disables emergency mode
     * Only callable by admin
     */
    function disableEmergency() external onlyAdmin {
        deploymentState = DeploymentState.Active;
        emit EmergencyModeDisabled(msg.sender);
    }

    // =============================================================
    // ROLE MANAGEMENT - Privilege Escalation
    // =============================================================
    
    /**
     * @dev Grants admin role to specified address
     * @param user Address to receive admin privileges
     * Only callable by deployer
     */
    function grantAdmin(address user) external onlyDeployer {
        roles[user] = Role.ADMIN;
        emit RoleGranted(user, Role.ADMIN);
    }

    // =============================================================
    // WITHDRAWAL LOGIC - Pull Payment Pattern
    // =============================================================
    
    /**
     * @dev Requests withdrawal amount to be added to pending queue
     * @param amount Amount of ETH to request for withdrawal
     * 
     * Requirements:
     * - Caller must be deployer
     * - Contract must be active
     * - Contract must not be in emergency
     * - Amount must be positive
     * - Amount must not exceed MAX_WITHDRAW_PER_TX
     */
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

    /**
     * @dev Processes pending withdrawal for caller
     * Implements pull payment pattern with cooldown
     * 
     * Requirements:
     * - Must have pending withdrawal amount > 0
     * - Must respect cooldown period between withdrawals
     * - Contract must have sufficient balance
     */
    function withdraw() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        if (amount == 0) revert ZeroAmount();

        // Check cooldown period
        uint256 lastTime = lastWithdrawTime[msg.sender];
        if (block.timestamp < lastTime + WITHDRAW_COOLDOWN)
            revert WithdrawCooldownActive(
                (lastTime + WITHDRAW_COOLDOWN) - block.timestamp
            );

        // Clear state before transfer (Checks-Effects-Interactions pattern)
        pendingWithdrawals[msg.sender] = 0;
        lastWithdrawTime[msg.sender] = block.timestamp;
        totalEtherWithdrawn += amount;

        // Transfer ETH
        payable(msg.sender).transfer(amount);
        emit EtherWithdrawn(msg.sender, amount);
    }

    // =============================================================
    // TRY / CATCH EXTERNAL CALL DEMO - Robust External Interactions
    // =============================================================
    
    /**
     * @dev Attempts external call with try/catch pattern
     * @param target Address of contract to call
     * @param data Calldata for external call
     * @return success Boolean indicating call success
     * @return response Bytes returned from external call
     */
    function callExternal(address target, bytes calldata data)
        external
        onlyAdmin
        returns (bool, bytes memory)
    {
        // Using try/catch to handle external call failures gracefully
        try this._externalCall(target, data) returns (bytes memory response) {
            emit ExternalCallResult(true, response);
            return (true, response);
        } catch {
            emit ExternalCallResult(false, "");
            revert ExternalCallFailed();
        }
    }

    /**
     * @dev Internal function for external calls
     * Separated to allow try/catch pattern
     * @param target Address of contract to call
     * @param data Calldata for external call
     * @return result Bytes returned from external call
     */
    function _externalCall(address target, bytes calldata data)
        external
        returns (bytes memory result)
    {
        (bool success, bytes memory result) = target.call(data);
        require(success, "Low-level call failed");
        return result;
    }

    // =============================================================
    // VIEW FUNCTIONS - State Queries
    // =============================================================
    
    /**
     * @dev Returns current contract balance
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Returns pending withdrawal amount for user
     * @param user Address to query
     */
    function getPendingWithdrawal(address user)
        external
        view
        returns (uint256)
    {
        return pendingWithdrawals[user];
    }

    /**
     * @dev Returns role of specified user
     * @param user Address to query
     */
    function getRole(address user) external view returns (Role) {
        return roles[user];
    }

    /**
     * @dev Returns complete deployment summary
     * @return _deployer Deployer address
     * @return _state Current deployment state
     * @return _timestamp Deployment timestamp
     * @return _received Total ETH received
     * @return _withdrawn Total ETH withdrawn
     * @return _status Last status message
     */
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
