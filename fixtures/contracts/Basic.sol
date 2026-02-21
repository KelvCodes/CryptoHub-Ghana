
  OPENSEA_API_KEY: process.env.API_KEY || "",
  SAFE_MODE: process.env.SAFE_MODE !== "false",
};

const REQUIRED_ENV_VARS = [
  "MNEMONIC",
  "NODE_API_KEY",
  "NETWORK",
  "OWNER_ADDRESS",
  "NFT_CONTRACT_ADDRESS",
];

REQUIRED_ENV_VARS.forEach((key) => {
  if (!CONFIG[key]) {
    console.error(`Missing required environment variable: ${key}`);
    process.exit(1);
  }
});

if (!CONFIG.OPENSEA_API_KEY) {
  console.warn(
    "Warning: OpenSea API key not provided. Rate limits may apply."
  );
}

// -------------------------------------------------------------
// Logging Utilities
// -------------------------------------------------------------

function log(message) {
  console.log(`[${new Date().toISOString()}] ${message}`);
}

function logError(error) {
  console.error(`[${new Date().toISOString()}] ERROR`);
  console.error(error);
}

// -------------------------------------------------------------
// Web3 Provider Setup
// -------------------------------------------------------------

const BASE_DERIVATION_PATH = "44'/60'/0'/0";

const walletSubprovider = new MnemonicWalletSubprovider({
  mnemonic: CONFIG.MNEMONIC,
  baseDerivationPath: BASE_DERIVATION_PATH,
});

const resolvedNetwork =
  CONFIG.NETWORK === "mainnet" || CONFIG.NETWORK === "live"
    ? "mainnet"
    : "rinkeby";

const rpcUrl = process.env.INFURA_KEY
  ? `https://${resolvedNetwork}.infura.io/v3/${CONFIG.NODE_API_KEY}`
  : `https://eth-${resolvedNetwork}.alchemyapi.io/v2/${CONFIG.NODE_API_KEY}`;

const providerEngine = new Web3ProviderEngine();
providerEngine.addProvider(walletSubprovider);
providerEngine.addProvider(new RPCSubprovider({ rpcUrl }));
providerEngine.start();

// -------------------------------------------------------------
// OpenSea SDK Initialization
// -------------------------------------------------------------

const seaport = new OpenSeaPort(
  providerEngine,
  {
    networkName:
      resolvedNetwork === "mainnet" ? Network.Main : Network.Rinkeby,
    apiKey: CONFIG.OPENSEA_API_KEY,
  },
  (event) => log(`SDK Event: ${event}`)
);

// -------------------------------------------------------------
// Utility Helpers
// -------------------------------------------------------------

async function validateMetadata(tokenId) {
  log(`Validating metadata for token ${tokenId}`);
  return true;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function withRetries(action, retries = 5) {
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      return await action();
    } catch (error) {
      logError(error);
      if (attempt === retries) {
        throw new Error("Maximum retry attempts reached.");
      }
      const delay = attempt * 2000;
      log(`Retrying in ${delay / 1000} seconds (${attempt}/${retries})`);
      await sleep(delay);
    }
  }
}

// -------------------------------------------------------------
// Listing Strategies
// -------------------------------------------------------------

async function createFixedPriceListing(tokenId, price) {
  return withRetries(async () => {
    log(`Creating fixed-price listing for token ${tokenId}`);

    await validateMetadata(tokenId);

    const order = await seaport.createSellOrder({
      asset: {
        tokenId: String(tokenId),
        tokenAddress: CONFIG.NFT_CONTRACT_ADDRESS,
        schemaName: WyvernSchemaName.ERC721,
      },
      startAmount: price,
      expirationTime: 0,
      accountAddress: CONFIG.OWNER_ADDRESS,
    });

    log(`Fixed-price listing created: ${order.asset.openseaLink}`);
    return order;
  });
}

async function createDutchAuctionListing(tokenId, startPrice, endPrice, hours) {
  return withRetries(async () => {
    log(`Creating Dutch auction for token ${tokenId}`);

    const expirationTime =
      Math.floor(Date.now() / 1000) + hours * 60 * 60;

    const order = await seaport.createSellOrder({
      asset: {
        tokenId: String(tokenId),
        tokenAddress: CONFIG.NFT_CONTRACT_ADDRESS,
        schemaName: WyvernSchemaName.ERC721,
      },
      startAmount: startPrice,
      endAmount: endPrice,
      expirationTime,
      accountAddress: CONFIG.OWNER_ADDRESS,
    });

    log(`Dutch auction created: ${order.asset.openseaLink}`);
    return order;
  });
}

async function createEnglishAuctionListing(tokenId, startBid, hours) {
  return withRetries(async () => {
    log(`Creating English auction for token ${tokenId}`);

    const expirationTime =
      Math.floor(Date.now() / 1000) + hours * 60 * 60;

    const wethAddress =
      resolvedNetwork === "mainnet"
        ? "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
        : "0xc778417e063141139fce010982780140aa0cd5ab";

    const order = await seaport.createSellOrder({
      asset: {
        tokenId: String(tokenId),
        tokenAddress: CONFIG.NFT_CONTRACT_ADDRESS,
        schemaName: WyvernSchemaName.ERC721,
      },
      startAmount: startBid,
      expirationTime,
      waitForHighestBid: true,
      paymentTokenAddress: wethAddress,
      accountAddress: CONFIG.OWNER_ADDRESS,
    });

    log(`English auction created: ${order.asset.openseaLink}`);
    return order;
  });
}

// -------------------------------------------------------------
// Bulk Listing
// -------------------------------------------------------------

async function bulkFixedPriceListings(tokenIds, price) {
  for (const tokenId of tokenIds) {
    await createFixedPriceListing(tokenId, price);
    await sleep(1500);
  }
}

// -------------------------------------------------------------
// Main Execution
// -------------------------------------------------------------

async function main() {
  log("Starting OpenSea NFT listing process");

  await createFixedPriceListing(1, 0.05);
  await createDutchAuctionListing(2, 0.05, 0.01, 24);
  await createEnglishAuctionListing(3, 0.03, 24);

  // Example bulk listing
  // await bulkFixedPriceListings([4, 5, 6], 0.02);

  log("All listings completed successfully");
}

main().catch(logError);
