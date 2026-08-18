const { CosmosClient } = require('@azure/cosmos');
const { BlobServiceClient } = require('@azure/storage-blob');

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

// Connection-string-based, not managed identity/RBAC - the training subscription's service
// principal has no Microsoft.Authorization/roleAssignments/write rights to grant Storage Blob
// Data Contributor, so this follows the same Key-Vault-secret-injected-by-the-pipeline pattern
// as the Cosmos key instead.
function getOrdersBlobContainerClient() {
  if (!blobContainerClient) {
    const connectionString = process.env.STORAGE_CONNECTION_STRING;
    const containerName = process.env.ORDERS_CONTAINER_NAME || 'orders';
    if (!connectionString) {
      throw new Error('STORAGE_CONNECTION_STRING is not set');
    }
    const blobServiceClient = BlobServiceClient.fromConnectionString(connectionString);
    blobContainerClient = blobServiceClient.getContainerClient(containerName);
  }
  return blobContainerClient;
}

module.exports = { getCosmosContainer, getOrdersBlobContainerClient };
