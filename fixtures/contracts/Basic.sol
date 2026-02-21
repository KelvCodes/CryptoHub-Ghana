

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
