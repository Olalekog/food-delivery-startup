# food-delivery-startup project

FoodFast is a food delivery startup. Orders come in through a web API, every order must be stored, the operations team must be notified of big orders automatically,
and the whole platform must be reproducible from code.

Use IaC Terraform in a pipeline to provision: a storage account with a container named orders, a Key Vault, a Cosmos DB account (NoSQL, free tier or serverless)
with database FoodFast and container Orders partitioned on /city, and a Linux Web App.

Build a Node.js API on the Web App, deployed only via CI/CD:

POST /api/orders saves an order (id, city, customerName, amount, items) to Cosmos DB and also writes the order as a JSON file into the orders blob container;
GET /api/orders returns all orders.

Cosmos key lives in Key Vault and is injected by the pipeline.

Create a Function App (blob trigger, Event Grid source) that fires when an order JSON lands in the container and logs the order amount.

Create a Logic App on the same container that checks the file and, if it is a .json file, emails you "New order received" with the file name, and creates no email for other
file types (condition step).

Prove the chain live: one POST to the API results in a Cosmos document, a blob, a function log entry, and an email, all within a minute.
