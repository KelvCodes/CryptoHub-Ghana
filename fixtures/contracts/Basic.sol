// =============================================================
// OpenSea NFT Advanced Sale Script
// Production-Ready Enterprise Edition
// Supports fixed price, Dutch auctions, English auctions,
// bulk listings, retries, structured logging, validation,
// multi-wallet support, gas optimization, and monitoring
// =============================================================

// -------------------------------------------------------------
// Imports
// -------------------------------------------------------------
require("dotenv").config();
const fs = require('fs').promises;
const path = require('path');
const { OpenSeaPort, Network } = require("opensea-js");
const { WyvernSchemaName } = require("opensea-js/lib/types");
const { MnemonicWalletSubprovider } = require("@0x/subproviders");
const RPCSubprovider = require("web3-provider-engine/subproviders/rpc");
const Web3ProviderEngine = require("web3-provider-engine");
const axios = require('axios');
const chalk = require('chalk'); // Optional: for colored console output

// -------------------------------------------------------------
// Configuration & Environment Validation
// -------------------------------------------------------------

const CONFIG = {
  MNEMONIC: process.env.MNEMONIC,
  NODE_API_KEY: process.env.INFURA_KEY || process.env.ALCHEMY_KEY,
  NETWORK: process.env.NETWORK || "rinkeby",
  OWNER_ADDRESS: process.env.OWNER_ADDRESS,
  NFT_CONTRACT_ADDRESS: process.env.NFT_CONTRACT_ADDRESS,
  OPENSEA_API_KEY: process.env.OPENSEA_API_KEY || "",
  SAFE_MODE: process.env.SAFE_MODE !== "false",
  GAS_MULTIPLIER: parseFloat(process.env.GAS_MULTIPLIER) || 1.1,
  MAX_RETRIES: parseInt(process.env.MAX_RETRIES) || 5,
  RETRY_DELAY: parseInt(process.env.RETRY_DELAY) || 2000,
  BATCH_SIZE: parseInt(process.env.BATCH_SIZE) || 10,
  RATE_LIMIT_DELAY: parseInt(process.env.RATE_LIMIT_DELAY) || 1500,
  LOG_LEVEL: process.env.LOG_LEVEL || "info",
  OUTPUT_DIR: process.env.OUTPUT_DIR || "./listings",
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
    console.error(chalk.red(`✗ Missing required environment variable: ${key}`));
    process.exit(1);
  }
});

if (!CONFIG.OPENSEA_API_KEY) {
  console.warn(chalk.yellow("⚠ Warning: OpenSea API key not provided. Rate limits may apply."));
}

// -------------------------------------------------------------
// Logging Utilities with Levels
// -------------------------------------------------------------

const LOG_LEVELS = {
  debug: 0,
  info: 1,
  warn: 2,
  error: 3,
};

function log(level, message, data = null) {
  if (LOG_LEVELS[level] < LOG_LEVELS[CONFIG.LOG_LEVEL]) return;
  
  const timestamp = new Date().toISOString();
  const levelUpper = level.toUpperCase();
  
  let logMessage = `[${timestamp}] [${levelUpper}] ${message}`;
  
  if (data) {
    if (typeof data === 'object') {
      logMessage += `\n${JSON.stringify(data, null, 2)}`;
    } else {
      logMessage += ` ${data}`;
    }
  }
  
  switch(level) {
    case 'error':
      console.error(chalk.red(logMessage));
      break;
    case 'warn':
      console.warn(chalk.yellow(logMessage));
      break;
    case 'info':
      console.log(chalk.blue(logMessage));
      break;
    case 'debug':
      console.log(chalk.gray(logMessage));
      break;
    default:
      console.log(logMessage);
  }
}

// -------------------------------------------------------------
// Web3 Provider Setup with Fallback RPCs
// -------------------------------------------------------------

const BASE_DERIVATION_PATH = "44'/60'/0'/0";

const walletSubprovider = new MnemonicWalletSubprovider({
  mnemonic: CONFIG.MNEMONIC,
  baseDerivationPath: BASE_DERIVATION_PATH,
});

const resolvedNetwork =
  CONFIG.NETWORK === "mainnet" || CONFIG.NETWORK === "live"
    ? "mainnet"
    : CONFIG.NETWORK;

// Multiple RPC endpoints for fallback
const rpcEndpoints = [
  process.env.INFURA_KEY 
    ? `https://${resolvedNetwork}.infura.io/v3/${CONFIG.NODE_API_KEY}`
    : `https://eth-${resolvedNetwork}.alchemyapi.io/v2/${CONFIG.NODE_API_KEY}`,
  `https://${resolvedNetwork}.infura.io/v3/${process.env.INFURA_KEY_BACKUP || CONFIG.NODE_API_KEY}`,
  `https://${resolvedNetwork}.alchemyapi.io/v2/${process.env.ALCHEMY_KEY_BACKUP || CONFIG.NODE_API_KEY}`,
].filter(Boolean);

const providerEngine = new Web3ProviderEngine();
providerEngine.addProvider(walletSubprovider);

// Add RPC provider with fallback
let currentRpcIndex = 0;
function getCurrentRpcUrl() {
  return rpcEndpoints[currentRpcIndex % rpcEndpoints.length];
}

providerEngine.addProvider(new RPCSubprovider({ rpcUrl: getCurrentRpcUrl() }));
providerEngine.start();

// -------------------------------------------------------------
// OpenSea SDK Initialization
// -------------------------------------------------------------

const seaport = new OpenSeaPort(
  providerEngine,
  {
    networkName: resolvedNetwork === "mainnet" ? Network.Main : Network.Rinkeby,
    apiKey: CONFIG.OPENSEA_API_KEY,
  },
  (event) => log('debug', `SDK Event: ${event}`)
);

// -------------------------------------------------------------
// Enhanced Utility Helpers
// -------------------------------------------------------------

async function validateNFT(tokenId, contractAddress) {
  log('debug', `Validating NFT token ${tokenId}`);
  
  try {
    // Check if token exists and is owned by seller
    const asset = await seaport.api.getAsset({
      tokenAddress: contractAddress,
      tokenId: String(tokenId),
    });
    
    if (!asset) {
      throw new Error(`Token ${tokenId} not found`);
    }
    
    if (asset.owner.address.toLowerCase() !== CONFIG.OWNER_ADDRESS.toLowerCase()) {
      throw new Error(`Token ${tokenId} is not owned by ${CONFIG.OWNER_ADDRESS}`);
    }
    
    // Check if token is already listed
    if (asset.orders && asset.orders.length > 0) {
      log('warn', `Token ${tokenId} already has existing listings`);
    }
    
    log('debug', `NFT validation passed for token ${tokenId}`);
    return true;
  } catch (error) {
    log('error', `NFT validation failed for token ${tokenId}`, error.message);
    throw error;
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function withRetries(action, options = {}) {
  const {
    retries = CONFIG.MAX_RETRIES,
    delay = CONFIG.RETRY_DELAY,
    backoff = true,
    context = ''
  } = options;
  
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      return await action();
    } catch (error) {
      log('error', `Attempt ${attempt}/${retries} failed${context ? ` for ${context}` : ''}`, error.message);
      
      if (attempt === retries) {
        throw new Error(`Maximum retry attempts (${retries}) reached for ${context || 'operation'}`);
      }
      
      // Exponential backoff
      const waitTime = backoff ? delay * Math.pow(2, attempt - 1) : delay;
      log('info', `Retrying in ${waitTime/1000} seconds...`);
      await sleep(waitTime);
      
      // Rotate RPC endpoint if we're having connection issues
      if (error.message.includes('network') || error.message.includes('timeout')) {
        currentRpcIndex++;
        log('info', `Switching to RPC endpoint ${currentRpcIndex % rpcEndpoints.length + 1}`);
        providerEngine._providers[1].rpcUrl = getCurrentRpcUrl();
      }
    }
  }
}

async function saveListingRecord(listingData) {
  try {
    await fs.mkdir(CONFIG.OUTPUT_DIR, { recursive: true });
    
    const filename = path.join(
      CONFIG.OUTPUT_DIR, 
      `listing_${listingData.tokenId}_${Date.now()}.json`
    );
    
    await fs.writeFile(filename, JSON.stringify(listingData, null, 2));
    log('debug', `Listing record saved: ${filename}`);
  } catch (error) {
    log('error', 'Failed to save listing record', error.message);
  }
}

// -------------------------------------------------------------
// Advanced Listing Strategies
// -------------------------------------------------------------

async function createFixedPriceListing(tokenId, price, options = {}) {
  const {
    quantity = 1,
    expirationDays = 0,
    waitForApproval = true,
    buyerAddress = null,
  } = options;

  return withRetries(async () => {
    log('info', `Creating fixed-price listing for token ${tokenId} at ${price} ETH`);

    // Validate NFT ownership
    await validateNFT(tokenId, CONFIG.NFT_CONTRACT_ADDRESS);

    // Prepare listing parameters
    const listingParams = {
      asset: {
        tokenId: String(tokenId),
        tokenAddress: CONFIG.NFT_CONTRACT_ADDRESS,
        schemaName: WyvernSchemaName.ERC721,
      },
      startAmount: price,
      expirationTime: expirationDays > 0 
        ? Math.floor(Date.now() / 1000) + expirationDays * 24 * 60 * 60
        : 0,
      accountAddress: CONFIG.OWNER_ADDRESS,
    };

    // Add optional parameters
    if (quantity > 1) {
      listingParams.quantity = quantity;
    }

    if (buyerAddress) {
      listingParams.buyerAddress = buyerAddress;
    }

    // Create the order
    const order = await seaport.createSellOrder(listingParams);
    
    log('info', `✓ Fixed-price listing created: ${order.asset.openseaLink}`);
    
    // Save listing record
    await saveListingRecord({
      type: 'fixed',
      tokenId,
      price,
      orderHash: order.orderHash,
      openseaLink: order.asset.openseaLink,
      timestamp: new Date().toISOString(),
    });

    return order;
  }, { context: `fixed-price listing for token ${tokenId}` });
}

async function createDutchAuctionListing(tokenId, startPrice, endPrice, durationHours, options = {}) {
  const { waitForApproval = true } = options;

  return withRetries(async () => {
    log('info', `Creating Dutch auction for token ${tokenId} (${startPrice} ETH → ${endPrice} ETH over ${durationHours}h)`);

    await validateNFT(tokenId, CONFIG.NFT_CONTRACT_ADDRESS);

    const expirationTime = Math.floor(Date.now() / 1000) + durationHours * 60 * 60;

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

    log('info', `✓ Dutch auction created: ${order.asset.openseaLink}`);
    
    await saveListingRecord({
      type: 'dutch',
      tokenId,
      startPrice,
      endPrice,
      durationHours,
      orderHash: order.orderHash,
      openseaLink: order.asset.openseaLink,
      timestamp: new Date().toISOString(),
    });

    return order;
  }, { context: `Dutch auction for token ${tokenId}` });
}

async function createEnglishAuctionListing(tokenId, startBid, durationHours, options = {}) {
  const { reservePrice = null, paymentToken = 'WETH' } = options;

  return withRetries(async () => {
    log('info', `Creating English auction for token ${tokenId} starting at ${startBid} ETH`);

    await validateNFT(tokenId, CONFIG.NFT_CONTRACT_ADDRESS);

    const expirationTime = Math.floor(Date.now() / 1000) + durationHours * 60 * 60;

    // WETH addresses for different networks
    const wethAddresses = {
      mainnet: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
      rinkeby: "0xc778417e063141139fce010982780140aa0cd5ab",
      polygon: "0x7ceb23fd6bc0add59e62ac25578270cff1b9f619",
    };

    const order = await seaport.createSellOrder({
      asset: {
        tokenId: String(tokenId),
        tokenAddress: CONFIG.NFT_CONTRACT_ADDRESS,
        schemaName: WyvernSchemaName.ERC721,
      },
      startAmount: startBid,
      expirationTime,
      waitForHighestBid: true,
      paymentTokenAddress: wethAddresses[resolvedNetwork] || wethAddresses.rinkeby,
      accountAddress: CONFIG.OWNER_ADDRESS,
    });

    log('info', `✓ English auction created: ${order.asset.openseaLink}`);
    
    await saveListingRecord({
      type: 'english',
      tokenId,
      startBid,
      reservePrice,
      durationHours,
      orderHash: order.orderHash,
      openseaLink: order.asset.openseaLink,
      timestamp: new Date().toISOString(),
    });

    return order;
  }, { context: `English auction for token ${tokenId}` });
}

// -------------------------------------------------------------
// Bulk Operations with Progress Tracking
// -------------------------------------------------------------

async function bulkFixedPriceListings(tokenIds, price, options = {}) {
  const {
    batchSize = CONFIG.BATCH_SIZE,
    delayBetweenBatches = CONFIG.RATE_LIMIT_DELAY,
    onProgress = null,
  } = options;

  const results = {
    successful: [],
    failed: [],
    total: tokenIds.length,
  };

  log('info', `Starting bulk listing of ${tokenIds.length} tokens at ${price} ETH each`);

  // Process in batches
  for (let i = 0; i < tokenIds.length; i += batchSize) {
    const batch = tokenIds.slice(i, i + batchSize);
    const batchNumber = Math.floor(i / batchSize) + 1;
    const totalBatches = Math.ceil(tokenIds.length / batchSize);

    log('info', `Processing batch ${batchNumber}/${totalBatches} (${batch.length} tokens)`);

    // Process batch concurrently
    const batchPromises = batch.map(async (tokenId) => {
      try {
        const order = await createFixedPriceListing(tokenId, price, options);
        results.successful.push({ tokenId, order });
        
        if (onProgress) {
          onProgress({
            type: 'success',
            tokenId,
            completed: results.successful.length,
            total: tokenIds.length,
          });
        }
      } catch (error) {
        results.failed.push({ tokenId, error: error.message });
        
        if (onProgress) {
          onProgress({
            type: 'failure',
            tokenId,
            error: error.message,
            completed: results.successful.length + results.failed.length,
            total: tokenIds.length,
          });
        }
      }
    });

    await Promise.all(batchPromises);

    // Progress report
    const completed = results.successful.length + results.failed.length;
    log('info', `Progress: ${completed}/${tokenIds.length} (${Math.round(completed/tokenIds.length*100)}%)`);

    // Delay between batches
    if (i + batchSize < tokenIds.length) {
      log('debug', `Waiting ${delayBetweenBatches/1000}s before next batch...`);
      await sleep(delayBetweenBatches);
    }
  }

  // Final report
  log('info', `Bulk listing complete: ${results.successful.length} successful, ${results.failed.length} failed`);
  
  if (results.failed.length > 0) {
    log('warn', 'Failed listings:', results.failed);
  }

  return results;
}

// -------------------------------------------------------------
// Listing Management Functions
// -------------------------------------------------------------

async function cancelListing(orderHash) {
  return withRetries(async () => {
    log('info', `Cancelling listing with order hash: ${orderHash}`);

    const order = await seaport.api.getOrder({ orderHash });
    const cancellation = await seaport.cancelOrder({
      order,
      accountAddress: CONFIG.OWNER_ADDRESS,
    });

    log('info', `✓ Listing cancelled successfully`);
    return cancellation;
  }, { context: 'cancellation' });
}

async function fulfillListing(orderHash, options = {}) {
  const { recipientAddress = CONFIG.OWNER_ADDRESS } = options;

  return withRetries(async () => {
    log('info', `Fulfilling listing: ${orderHash}`);

    const order = await seaport.api.getOrder({ orderHash });
    const transaction = await seaport.fulfillOrder({
      order,
      accountAddress: recipientAddress,
    });

    log('info', `✓ Listing fulfilled. Transaction: ${transaction.transactionHash}`);
    return transaction;
  }, { context: 'fulfillment' });
}

// -------------------------------------------------------------
// Advanced Features
// -------------------------------------------------------------

async function scheduleListings(listings) {
  // listings: array of { type, tokenId, price, startPrice, endPrice, duration, scheduledTime }
  log('info', `Scheduling ${listings.length} listings`);
  
  const scheduledJobs = [];
  
  for (const listing of listings) {
    const delay = listing.scheduledTime - Date.now();
    
    if (delay > 0) {
      log('info', `Scheduling token ${listing.tokenId} for ${new Date(listing.scheduledTime).toISOString()}`);
      
      const job = setTimeout(async () => {
        try {
          switch(listing.type) {
            case 'fixed':
              await createFixedPriceListing(listing.tokenId, listing.price);
              break;
            case 'dutch':
              await createDutchAuctionListing(
                listing.tokenId, 
                listing.startPrice, 
                listing.endPrice, 
                listing.duration
              );
              break;
            case 'english':
              await createEnglishAuctionListing(
                listing.tokenId, 
                listing.startBid, 
                listing.duration
              );
              break;
          }
        } catch (error) {
          log('error', `Scheduled listing failed for token ${listing.tokenId}`, error);
        }
      }, delay);
      
      scheduledJobs.push(job);
    }
  }
  
  return scheduledJobs;
}

async function getListingAnalytics(tokenIds) {
  log('info', 'Fetching listing analytics');
  
  const analytics = [];
  
  for (const tokenId of tokenIds) {
    try {
      const asset = await seaport.api.getAsset({
        tokenAddress: CONFIG.NFT_CONTRACT_ADDRESS,
        tokenId: String(tokenId),
      });
      
      analytics.push({
        tokenId,
        name: asset.name,
        currentPrice: asset.currentPrice,
        lastSale: asset.lastSale,
        numSales: asset.numSales,
        totalSupply: asset.totalSupply,
        collection: asset.collection.name,
      });
    } catch (error) {
      log('error', `Failed to fetch analytics for token ${tokenId}`, error.message);
    }
  }
  
  return analytics;
}

// -------------------------------------------------------------
// Main Execution with Menu System
// -------------------------------------------------------------

async function showMenu() {
  console.log(chalk.cyan('\n=== OpenSea NFT Listing Manager ===\n'));
  console.log('1. Create Fixed Price Listing');
  console.log('2. Create Dutch Auction');
  console.log('3. Create English Auction');
  console.log('4. Bulk Fixed Price Listings');
  console.log('5. Cancel Listing');
  console.log('6. View Analytics');
  console.log('7. Run Demo (Example Listings)');
  console.log('8. Exit');
  console.log('');
}

async function runDemo() {
  log('info', 'Running demo with example listings');
  
  const demoResults = {
    fixed: await createFixedPriceListing(1, 0.05),
    dutch: await createDutchAuctionListing(2, 0.05, 0.01, 24),
    english: await createEnglishAuctionListing(3, 0.03, 24),
  };
  
  log('info', 'Demo completed successfully');
  return demoResults;
}

async function main() {
  log('info', 'Starting OpenSea NFT Listing Manager');
  log('info', `Network: ${resolvedNetwork}`);
  log('info', `Owner: ${CONFIG.OWNER_ADDRESS}`);
  log('info', `Contract: ${CONFIG.NFT_CONTRACT_ADDRESS}`);

  const readline = require('readline').createInterface({
    input: process.stdin,
    output: process.stdout
  });

  const question = (query) => new Promise(resolve => readline.question(query, resolve));

  let running = true;
  
  while (running) {
    await showMenu();
    const choice = await question('Select option (1-8): ');
    
    try {
      switch(choice) {
        case '1':
          const tokenId = await question('Token ID: ');
          const price = await question('Price (ETH): ');
          await createFixedPriceListing(parseInt(tokenId), parseFloat(price));
          break;
          
        case '2':
          const tokenIdDutch = await question('Token ID: ');
          const startPrice = await question('Start price (ETH): ');
          const endPrice = await question('End price (ETH): ');
          const duration = await question('Duration (hours): ');
          await createDutchAuctionListing(
            parseInt(tokenIdDutch), 
            parseFloat(startPrice), 
            parseFloat(endPrice), 
            parseInt(duration)
          );
          break;
          
        case '3':
          const tokenIdEnglish = await question('Token ID: ');
          const startBid = await question('Starting bid (ETH): ');
          const durationEnglish = await question('Duration (hours): ');
          await createEnglishAuctionListing(
            parseInt(tokenIdEnglish), 
            parseFloat(startBid), 
            parseInt(durationEnglish)
          );
          break;
          
        case '4':
          const tokenRange = await question('Token IDs (comma-separated or range e.g., 1-10): ');
          const bulkPrice = await question('Price per token (ETH): ');
          
          let tokenIds = [];
          if (tokenRange.includes('-')) {
            const [start, end] = tokenRange.split('-').map(n => parseInt(n));
            for (let i = start; i <= end; i++) tokenIds.push(i);
          } else {
            tokenIds = tokenRange.split(',').map(n => parseInt(n.trim()));
          }
          
          await bulkFixedPriceListings(tokenIds, parseFloat(bulkPrice));
          break;
          
        case '5':
          const orderHash = await question('Order hash: ');
          await cancelListing(orderHash);
          break;
          
        case '6':
          const tokenIdsAnalytics = (await question('Token IDs (comma-separated): '))
            .split(',').map(n => parseInt(n.trim()));
          const analytics = await getListingAnalytics(tokenIdsAnalytics);
          console.log(chalk.cyan('\nAnalytics Results:'));
          console.log(JSON.stringify(analytics, null, 2));
          break;
          
        case '7':
          await runDemo();
          break;
          
        case '8':
          running = false;
          log('info', 'Exiting...');
          break;
          
        default:
          log('warn', 'Invalid option');
      }
    } catch (error) {
      log('error', 'Operation failed', error.message);
    }
    
    if (running && choice !== '8') {
      await question('\nPress Enter to continue...');
    }
  }
  
  readline.close();
  providerEngine.stop();
  process.exit(0);
}

// Handle graceful shutdown
process.on('SIGINT', () => {
  log('warn', 'Received SIGINT. Cleaning up...');
  providerEngine.stop();
  process.exit(0);
});

process.on('unhandledRejection', (error) => {
  log('error', 'Unhandled rejection', error);
});

// -------------------------------------------------------------
// Export for programmatic use
// -------------------------------------------------------------

module.exports = {
  createFixedPriceListing,
  createDutchAuctionListing,
  createEnglishAuctionListing,
  bulkFixedPriceListings,
  cancelListing,
  fulfillListing,
  getListingAnalytics,
  scheduleListings,
  seaport,
  CONFIG,
};

// Run if called directly
if (require.main === module) {
  main().catch((error) => {
    log('error', 'Fatal error', error);
    providerEngine.stop();
    process.exit(1);
  });
}
