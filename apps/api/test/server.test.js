const test = require('node:test');
const assert = require('node:assert/strict');
const app = require('../server');

test('GET /health returns status ok', async () => {
  const server = app.listen(0);
  const { port } = server.address();
  try {
    const res = await fetch(`http://localhost:${port}/health`);
    const body = await res.json();
    assert.equal(res.status, 200);
    assert.deepEqual(body, { status: 'ok' });
  } finally {
    server.close();
  }
});

test('POST /api/orders with an invalid body returns 400 before touching Cosmos/Blob', async () => {
  const server = app.listen(0);
  const { port } = server.address();
  try {
    const res = await fetch(`http://localhost:${port}/api/orders`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ id: 'order-1' }),
    });
    const body = await res.json();
    assert.equal(res.status, 400);
    assert.match(body.error, /city/);
  } finally {
    server.close();
  }
});
