ETWORK === "mainnet" || NETWORK === "live" ? "mainnet" : "rinkeby";

/onst providerEngine = new Web3ProviderEngine();
= await seaport.createSellOrder({
    asset: {
      tokenId: "1", // Unique ID of the NFT
      tokenAddress: NFT_CONTRACT_ADDRESS, // Address of the NFT contract
      schemaName: WyvernSchemaName.ERC721 // NFT standard (ERC721 or ERC1155)
    },
    startAmount: 0.05, // Sale price in ETH
    expirationTime: 0, // 0 means the listing never expires
    accountAddress: OWNER_ADDRESS, // Address that owns and lists the NFT
  });

  console.log(
    `✅ Successfully created a fixed-price sell order!\n🔗 ${fixedPriceSellOrder.asset.openseaLink}\n`
  );

  // ✅ DUTCH AUCTION
  console.log("Dutch auctioning an item...");

  const expirationTime = Math.round(Date.now() / 1000 + 60 * 60 * 24); // Set expiration to 24 hours from now

  const dutchAuctionSellOrder = await seaport.createSellOrder({
    asset: {
      tokenId: "2",
      tokenAddress: NFT_CONTRACT_ADDRESS,
      schemaName: WyvernSchemaName.ERC721
    },
    startAmount: 0.05, // Starting price (ETH)
    endAmount: 0.01,   // Ending price as time expires
    expirationTime: expirationTime, // Time when auction ends
    accountAddress: OWNER_ADDRESS,
  });

  console.log(
    `✅ Successfully created a Dutch auction!\n🔗 ${dutchAuctionSellOrder.asset.openseaLink}\n`
  );

  // ✅ ENGLISH AUCTION (bidding)
  console.log("English auctioning an item in WETH...");

  // Determine the WETH address based on the network
  const wethAddress =
    NETWORK === "mainnet" || NETWORK === "live"
      ? "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2" // WETH Mainnet
      : "0xc778417e063141139fce010982780140aa0cd5ab"; // WETH Rinkeby

  const englishAuctionSellOrder = await seaport.createSellOrder({
    asset: {
      tokenId: "3",
      tokenAddress: NFT_CONTRACT_ADDRESS,
      schemaName: WyvernSchemaName.ERC721
    },
    startAmount: 0.03, // Starting bid price
    expirationTime: expirationTime,
    waitForHighestBid: true, // Enable competitive bidding (English auction)
    paymentTokenAddress: wethAddress, // Use WETH as payment currency
    accountAddress: OWNER_ADDRESS,
  });

  console.log(
    `✅ Successfully created an English auction!\n🔗 ${englishAuctionSellOrder.asset.openseaLink}\n`
  );
}

// Run the main function
main();

