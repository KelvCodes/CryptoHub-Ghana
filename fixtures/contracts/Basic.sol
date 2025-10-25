or deriving Ethereum accounts
const lletSubprovider = new MnemonicWalletSubprovider({
  mnemonic: MNEMONIC,
  baseDerivationPath: BASE_DERIVATION_PATH,
});

// Determine the network (mainnet or rinkeby)
const network = NETWORK === "mainnet" || NETWORK === "live" ? "mainnet" : "rinkeby";

// Configure RPC subprovider for Alchemy or Infura
const infuraRpcSubprovider = new RPCSubprovider({
  rpcUrl: isInfura
    ? `https://${network}.infura.io/v3/${NODE_API_KEY}`
    : `https://eth-${network}.alchemyapi.io/v2/${NODE_API_KEY}`,
});

// Combine wallet and RPC into a provider engine
const providerEngine = new Web3ProviderEngine();
providerEngine.addProvider(mnemonicWalletSubprovider);
providerEngine.addProvider(infuraRpcSubprovider);
providerEngine.start();

// Initialize the OpenSeaPort object with provider and API settings
const seaport = new OpenSeaPort(
  providerEngine,
  {
    networkName: NETWORK === "mainnet" || NETWORK === "live" ? Network.Main : Network.Rinkeby,
    apiKey: API_KEY,
  },
  (arg) => console.log(arg) // Log SDK events (optional)
);

// Main execution function
async function main() {
  // ✅ FIXED-PRICE SALE
  console.log("Auctioning an item for a fixed price...");

  const fixedPriceSellOrder = await seaport.createSellOrder({
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

