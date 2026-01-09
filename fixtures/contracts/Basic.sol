API key is missing
if (!CONFIG.API_KEY) {
  console.warn("⚠️  Running without OpenSea API key. Rate limits may apply.");
}

// -------------------------------------------------------------
//   LOGGING ENGINE
// -------------------------------------------------------------

function log(msg) {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${msg}`);
}

function logError(err) {
  const timestamp = new Date().toISOString();
  console.error(`\n[${timestamp}] ❌ ERROR `);
  console.error(err);
  console.error();
}

// -------------------------------------------------------------
//   WEB3 PROVIDER SETUP
// -------------------------------------------------------------

const BASE_DERIVATION_PATH = `44'/60'/0'/0`;

const mnemonicWalletSubprovider = new MnemonicWalletSubprovider({
  mnemonic: CONFIG.MNEMONIC,
  baseDerivationPath: BASE_DERIVATION_PATH,
});

const network =
  CONFIG.NETWORK === "mainnet" || CONFIG.NETWORK === "live"
    ? "mainnet"
    : "rinkeby";

const rpcUrl = process.env.INFURA_KEY
  ? `https://${network}.infura.io/v3/${CONFIG.NODE_API_KEY}`
  : `https://eth-${network}.alchemyapi.io/v2/${CONFIG.NODE_API_KEY}`;

const providerEngine = new Web3ProviderEngine();
providerEngine.addProvider(mnemonicWalletSubprovider);
providerEngine.addProvider(new RPCSubprovider({ rpcUrl }));
providerEngine.start();

// -------------------------------------------------------------
//   INITIALIZE OPENSEA SDK
// -------------------------------------------------------------

const { OpenSeaPort, Network } = opensea;

const seaport = new OpenSeaPort(
  providerEngine,
  {
    networkName:
      CONFIG.NETWORK === "mainnet" || CONFIG.NETWORK === "live"
        ? Network.Main
        : Network.Rinkeby,
    apiKey: CONFIG.API_KEY,
  },
  (event) => log(`📡 SDK Event: ${event}`)
);

// -------------------------------------------------------------
//   HELPER FUNCTIONS
// -------------------------------------------------------------

// Metadata validation (optional but recommended)
async function validateMetadata(tokenId) {
  // In real projects you would fetch actual metadata here
  log(`🔍 Validating metadata for token ${tokenId}...`);
  return true;
}

// Sleep utility (useful for rate limit protection)
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Retry wrapper for robust execution
async function safeExecute(fn, retries = 5) {
  for (let i = 0; i < retries; i++) {
    try {
      return await fn();
    } catch (err) {
      logError(err);
      const wait = 2000 * (i + 1);
      log(`⏳ Retrying in ${wait / 1000}s (${i + 1}/${retries})...`);
      await sleep(wait);
    }
  }
  throw new Error("❌ Max retries reached. Aborting.");
}

// -------------------------------------------------------------
//   SALE TEMPLATES
// -------------------------------------------------------------

async function createFixedPriceListing(tokenId, price) {
  return await safeExecute(async () => {
    log(`🛒 Creating FIXED PRICE listing for Token ${tokenId}...`);

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

    log(`✅ Fixed-price listing created: ${order.asset.openseaLink}`);
    return order;
  });
}

async function createDutchAuctionListing(tokenId, start, end, hours) {
  return await safeExecute(async () => {
    log(`⏬ Creating DUTCH AUCTION for Token ${tokenId}...`);

    const expirationTime = Math.round(Date.now() / 1000 + 60 * 60 * hours);

    const order = await seaport.createSellOrder({
      asset: {
        tokenId: String(tokenId),
        tokenAddress: CONFIG.NFT_CONTRACT_ADDRESS,
        schemaName: WyvernSchemaName.ERC721,
      },
      startAmount: start,
      endAmount: end,
      expirationTime,
      accountAddress: CONFIG.OWNER_ADDRESS,
    });

    log(`✅ Dutch auction created: ${order.asset.openseaLink}`);
    return order;
  });
}

async function createEnglishAuctionListing(tokenId, startBid, hours) {
  return await safeExecute(async () => {
    log(`🔨 Creating ENGLISH AUCTION for Token ${tokenId}...`);

    const expirationTime = Math.round(Date.now() / 1000 + 60 * 60 * hours);

    const weth =
      CONFIG.NETWORK === "mainnet" || CONFIG.NETWORK === "live"
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
      paymentTokenAddress: weth,
      accountAddress: CONFIG.OWNER_ADDRESS,
    });

    log(`✅ English auction created: ${order.asset.openseaLink}`);
    return order;
  });
}

// -------------------------------------------------------------
//   BULK LISTING ENGINE
// -------------------------------------------------------------

async function bulkListFixed(tokens, price) {
  for (const token of tokens) {
    await createFixedPriceListing(token, price);
    await sleep(1500); // avoid rate limit
  }
}

// -------------------------------------------------------------
//   MAIN EXECUTION FUNCTION
// -------------------------------------------------------------

async function main() {
  log("🚀 Starting OpenSea NFT Listing Script (Ultimate Edition)");

  await createFixedPriceListing(1, 0.05);
  await createDutchAuctionListing(2, 0.05, 0.01, 24);
  await createEnglishAuctionListing(3, 0.03, 24);

  // Optional: bulk listing
  // await bulkListFixed([4,5,6,7], 0.02);

  log("🎉 ALL LISTINGS COMPLETED");
}

// -------------------------------------------------------------
//   EXECUTE SCRIPT
// -------------------------------------------------------------

main().catch((err) => logError(err));

