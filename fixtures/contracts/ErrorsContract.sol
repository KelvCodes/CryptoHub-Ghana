icense-Identifier: GNU
pragma solidity ^0.8.13;

/// @title ErrorsContract - Demonstrates custom errors, secure Ether handling, and authorization
contract ErrorsContract {
    // =============================
    // ======== STATE VARS =========
    // =============================
    
    address payable public owner;

    // =============================
    // ======== CUSTOM ERRORS ======
    // =============================
    
    /// @notice Thrown when an unauthorized caller tries to execute a restricted function
    error Unauthorized(address caller);

    /// @notice Thrown when a custom logic condition fails
    error CustomError(string message);

    /// @notice Thrown when transfer of Ether fails
    error TransferFailed(uint256 amount, address to);

    // =============================
    // ========= EVENTS ===========
    // =============================
    
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event FundsTransferred(address indexed to, uint256 amount);
    event Received(address indexed from, uint256 amount);

    // =============================
    // ======== MODIFIERS =========
    // =============================
    
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized(msg.sender);
        _;
    }

    // =============================
    // ======== CONSTRUCTOR =======
    // =============================
    
    /// @notice Sets the deployer as the initial owner
    constructor() {
        owner = payable(msg.sender);
        emit OwnershipTransferred(address(0), owner);
    }

    // =============================
    // ======== FUNCTIONS =========
    // =============================

    /// @notice Transfers contract balance to the owner
    /// @dev Only callable by the owner
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) revert CustomError("No funds to withdraw");

        (bool success, ) = owner.call{value: balance}("");
        if (!success) revert TransferFailed(balance, owner);

        emit FundsTransferred(owner, balance);
    }

    /// @notice Demonstrates custom error usage
    function badRequire() external pure {
        // Always fails as a demonstration
        if (1 < 2) revert CustomError("Reverted using custom Error");
    }

    /// @notice Allows the owner to update ownership
    /// @param newOwner The new owner address
    function updateOwner(address payable newOwner) external onlyOwner {
        if (newOwner == address(0)) revert CustomError("Cannot set zero address as owner");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Receive Ether
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    /// @notice Fallback function
    fallback() external payable {
        emit Received(msg.sender, msg.value);
    }

    /// @notice Get the contract balance
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

