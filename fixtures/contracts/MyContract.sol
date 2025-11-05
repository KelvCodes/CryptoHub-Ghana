myAttribute;

    // Public function to retrieve the value of 'myAttribute'
    // The 'view' keyword indicates that this function does not modify the blockchain state
    // Returns: The stored string value of 'myAttribute'
    function getAttr() public view returns (string memory) {
        return myAttribute;
    }
}

