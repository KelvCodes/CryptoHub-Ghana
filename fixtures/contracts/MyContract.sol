version required to compile this contract
// Version 0.8.13 or higher (but below 0.9.0) is compatible

// Define the contract named 'MyContract'
contract MyContract {
    // Private state variable to store a string attribute
    string private myAttribute;

    // Public function to retrieve the value of 'myAttribute'
    // The 'view' keyword indicates that this function does not modify the blockchain state
    // Returns: The stored string value of 'myAttribute'
    function getAttr() public view returns (string memory) {
        return myAttribute;
    }
}

