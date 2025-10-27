y handle incremental counters
import '@openzeppelin/contracts/utils/Counters.sol';

// Define the ERC721Token contract inheriting from ERC721URIStorage
contract ERC721Token is ERC721URIStorage {
    // Use the Counters library for managing token IDs safely
    using Counters for Counters.Counter;
    // Private counter to keep track of token IDs minted so far
    Counters.Counter private _tokenIds;

    // Contract constructor sets the token name and symbol
    constructor() ERC721('GameItem', 'ITM') {}

    /**
     * @notice Mints a new token and assigns it to the specified player address
     * @dev Increments the token ID counter, mints the token, and sets its metadata URI
     * @param player The address of the player who will own the new token
     * @param tokenURI The metadata URI associated with the token (e.g., JSON metadata link)
     * @return The ID of the newly minted token
     */
    function awardItem(address player, string memory tokenURI) public returns (uint256) {
        // Get the current token ID from the counter
        uint256 newItemId = _tokenIds.current();

        // Mint a new token with ID `newItemId` to the player's address
        _mint(player, newItemId);

        // Assign the provided metadata URI to the minted token
        _setTokenURI(newItemId, tokenURI);

        // Increment the token ID counter for the next mint
        _tokenIds.increment();

        // Return the ID of the newly minted token
        return newItemId;
    }
}

