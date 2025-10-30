
     * @dev Allows the contract owner to update the base metadata URI
     */
    function setBaseURI(string memory newBaseURI) public onlyOwner {
        _baseTokenURI = newBaseURI;
    }

    /**
     * @dev Override _baseURI() to return the dynamic base URI
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }
}

