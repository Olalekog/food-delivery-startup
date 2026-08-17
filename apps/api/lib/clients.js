const { CosmosClient } = require('@azure/cosmos');
const { BlobServiceClient } = require('@azure/storage-blob');
const { DefaultAzureCredential } = require('@azure/identity');

// Lazily constructed so the module can be required (e.g. by tests) without live Azure
// credentials in the environment - only fails once a route actually needs a client.
let cosmosContainer;
let blobContainerClient;

function getCosmosContainer() {
  if (!cosmosContainer) {
    const endpoint = process.env.COSMOS_ENDPOINT;
    const key = process.env.COSMOS_KEY;
    if (!endpoint || !key) {
      throw new Error('COSMOS_ENDPOINT / COSMOS_KEY are not set');
    }
    const client = new CosmosClient({ endpoint, key });
    cosmosContainer = client.database('FoodFast').container('Orders');
  }
  return cosmosContainer;
}

// Uses the Web App's system-assigned managed identity (granted Storage Blob Data Contributor
// in Terraform) rather than a storage account key.
function getOrdersBlobContainerClient() {
  if (!blobContainerClient) {
    const accountName = process.env.STORAGE_ACCOUNT_NAME;
    const containerName = process.env.ORDERS_CONTAINER_NAME || 'orders';
    if (!accountName) {
      throw new Error('STORAGE_ACCOUNT_NAME is not set');
    }
    const blobServiceClient = new BlobServiceClient(
      `https://${accountName}.blob.core.windows.net`,
      new DefaultAzureCredential()
    );
    blobContainerClient = blobServiceClient.getContainerClient(containerName);
  }
  return blobContainerClient;
}

module.exports = { getCosmosContainer, getOrdersBlobContainerClient };
