===========
//   OpenSea NFT Sale Script
//  This script demonstrates how to list NFTs for sale on OpenSea
//  using fixed-price, Dutch auction, and English auction formats.
// =============================================================

// -------------------------------------------------------------
//   Import Required Modules
// -------------------------------------------------------------

// Import the OpenSea JS SDK and relevant types
const opensea = require("opensea-js");
const { WyvernSchemaName } = require("opensea-js/lib/types");

// Extract specific constants from the SDK
const { OpenSeaPort, Network } = opensea;

// Import Web3 provider tools and subproviders
const {
  MnemonicWalletSubprovider,
} = require("@0x/subproviders");
const RPCSubprovider = require("web3-provider-engine/subproviders/rpc");
const Web3ProviderEngine = require("web3-provider-engine");

// -------------------------------------------------------------
//   Load Environment Variables
// -------------------------------------------------------------

const MNEMONIC = process.env.MNEMONIC;
const NODE_API_KEY = process.env.INFURA_KEY || process.env.ALCHEMY_KEY;
const isInfura = !!process.env.INFURA_KEY;

const FACTORY_CONTRACT_ADDRESS = process.env.FACTORY_CONTRACT_ADDRESS;
const NFT_CONTRACT_ADDRESS = process.env.NFT_CONTRACT_ADDRESS;
const OWNER_ADDRESS = process.env.OWNER_ADDRESS;

const NETWORK = process.env.NETWORK;
const API_KEY = process.env.API_KEY || ""; // Optional but recommended

// -------------------------------------------------------------
//   Validate Environment Variables
// -------------------------------------------------------------

if (!MNEMONIC || !NODE_API_KEY || !NETWORK || !OWNER_ADDRESS) {
  console.error(
    " Missing configuration! Please set: MNEMONIC, API key (Alchemy/Infura), OWNER_ADDRESS, and NETWORK."
  );
  return;
}

if (!FACTORY_CONTRACT_ADDRESS && !NFT_CONTRACT_ADDRESS) {
  console.error(
    " Missing contract information! Please set either FACTORY_CONTRACT_ADDRESS or NFT_CONTRACT_ADDRESS."
  );
  return;
}

// -------------------------------------------------------------
//   Set Up Wallet and Provider Engine
// -------------------------------------------------------------

// Define HD wallet path for deterministic Ethereum address generation
const BASE_DERIVATION_PATH = `44'/60'/0'/0`;

// Create a wallet subprovider to handle private key signing
const mnemonicWalletSubprovider = new MnemonicWalletSubprovider({
  mnemonic: MNEMONIC,
  baseDerivationPath: BASE_DERIVATION_PATH,
});

// Determine which Ethereum network to connect to
const network =
  NETWORK === "mainnet" || NETWORK === "live"
    ? "mainnet"
    : "rinkeby";

// Configure RPC endpoint (Infura or Alchemy)
const rpcUrl = isInfura
  ? `https://${network}.infura.io/v3/${NODE_API_KEY}`
  : `https://eth-${network}.alchemyapi.io/v2/${NODE_API_KEY}`;

// Create RPC subprovider for blockchain communication
const infuraRpcSubprovider = new RPCSubprovider({
  rpcUrl,
});

// Combine wallet and RPC providers using a Provider Engine
const providerEngine = new Web3ProviderEngine();
providerEngine.addProvider(mnemonicWalletSubprovider);
providerEngine.addProvider(infuraRpcSubprovider);
providerEngine.start();

// -------------------------------------------------------------
//   Initialize OpenSea SDK
// -------------------------------------------------------------

// Instantiate the OpenSeaPort object with necessary configs
const seaport = new OpenSeaPort(
  providerEngine,
  {
    networkName:
      NETWORK === "mainnet" || NETWORK === "live"
        ? Network.Main
        : Network.Rinkeby,
    apiKey: API_KEY,
  },
  (event) => console.log("SDK Event:", event)
);

// -------------------------------------------------------------
//   Define Main Function
// -------------------------------------------------------------

async function main() {
  // ---------------------------------------------------------
  //  FIXED-PRICE SALE
  // ---------------------------------------------------------
  console.log(" Creating a fixed-price listing on OpenSea...");

  const fixedPriceSellOrder = await seaport.createSellOrder({
    asset: {
      tokenId: "1", // Unique ID of the NFT
      tokenAddress: NFT_CONTRACT_ADDRESS, // NFT contract address
      schemaName: WyvernSchemaName.ERC721, // NFT standard (ERC721)
    },
    startAmount: 0.05, // Sale price in ETH
    expirationTime: 0, // 0 means never expires
    accountAddress: OWNER_ADDRESS, // The address listing the NFT
  });

  console.log(" Fixed-price sale created successfully!");
  console.log(` View on OpenSea: ${fixedPriceSellOrder.asset.openseaLink}\n`);

  // ---------------------------------------------------------
  //  DUTCH AUCTION SALE
  // ---------------------------------------------------------
  console.log(" Creating a Dutch auction listing...");

  // Expiration time (24 hours from now)
  const expirationTime = Math.round(Date.now() / 1000 + 60 * 60 * 24);

  const dutchAuctionSellOrder = await seaport.createSellOrder({
    asset: {
      tokenId: "2",
      tokenAddress: NFT_CONTRACT_ADDRESS,
      schemaName: WyvernSchemaName.ERC721,
    },
    startAmount: 0.05, // Starting price
    endAmount: 0.01, // Ending price
    expirationTime: expirationTime, // Ends in 24 hours
    accountAddress: OWNER_ADDRESS,
  });

  console.log(" Dutch auction created successfully!");
  console.log(` View on OpenSea: ${dutchAuctionSellOrder.asset.openseaLink}\n`);

  // ---------------------------------------------------------
  //  ENGLISH AUCTION SALE
  // ---------------------------------------------------------
  console.log(" Creating an English auction (WETH bids)...");

  // Determine WETH token address based on network
  const wethAddress =
    NETWORK === "mainnet" || NETWORK === "live"
      ? "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2" // Mainnet WETH
      : "0xc778417e063141139fce010982780140aa0cd5ab"; // Rinkeby WETH

  const englishAuctionSellOrder = await seaport.createSellOrder({
    asset: {
      tokenId: "3",
      tokenAddress: NFT_CONTRACT_ADDRESS,
      schemaName: WyvernSchemaName.ERC721,
    },
    startAmount: 0.03, // Starting bid
    expirationTime: expirationTime, // Auction duration
    waitForHighestBid: true, // Enables bidding competition
    paymentTokenAddress: wethAddress, // Use WETH as currency
    accountAddress: OWNER_ADDRESS,
  });

  console.log("English auction created successfully!");
  console.log(` View on OpenSea: ${englishAuctionSellOrder.asset.openseaLink}\n`);

  // ---------------------------------------------------------
  //  Summary
  // ---------------------------------------------------------
  console.log(" All NFT listings completed successfully!");
  console.log(" Check your OpenSea profile to confirm your listings.");
}

// -------------------------------------------------------------
//   Execute the Main Function
// -------------------------------------------------------------

main()
  .then(() => {
    console.log(" Script execution finished successfully!");
  })
  .catch((error) => {
    console.error(" An error occurred while running the script:");
    console.error(error);
  });

// -------------------------------------------------------------
//  End of Script
// -------------------------------------------------------------

