const express = require('express');
const { validateOrder } = require('./lib/validateOrder');
const { getCosmosContainer, getOrdersBlobContainerClient } = require('./lib/clients');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.post('/api/orders', async (req, res) => {
  const validationError = validateOrder(req.body);
  if (validationError) {
    return res.status(400).json({ error: validationError });
  }

  const order = {
    id: req.body.id,
    city: req.body.city,
    customerName: req.body.customerName,
    amount: req.body.amount,
    items: req.body.items,
  };

  try {
    const container = getCosmosContainer();
    await container.items.create(order);

    const blockBlobClient = getOrdersBlobContainerClient().getBlockBlobClient(`${order.id}.json`);
    const body = JSON.stringify(order);
    await blockBlobClient.upload(body, Buffer.byteLength(body), {
      blobHTTPHeaders: { blobContentType: 'application/json' },
    });

    res.status(201).json(order);
  } catch (err) {
    console.error('Failed to save order', err);
    res.status(500).json({ error: 'Failed to save order' });
  }
});

app.get('/api/orders', async (req, res) => {
  try {
    const container = getCosmosContainer();
    const { resources } = await container.items.readAll().fetchAll();
    res.json(resources);
  } catch (err) {
    console.error('Failed to read orders', err);
    res.status(500).json({ error: 'Failed to read orders' });
  }
});

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`FoodFast API listening on port ${PORT}`);
  });
}

module.exports = app;
