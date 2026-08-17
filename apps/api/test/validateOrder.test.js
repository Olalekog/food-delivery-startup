const test = require('node:test');
const assert = require('node:assert/strict');
const { validateOrder } = require('../lib/validateOrder');

const validOrder = {
  id: 'order-1',
  city: 'Toronto',
  customerName: 'Jane Doe',
  amount: 24.5,
  items: ['burger', 'fries'],
};

test('accepts a well-formed order', () => {
  assert.equal(validateOrder(validOrder), null);
});

test('rejects a missing id', () => {
  const { id, ...rest } = validOrder;
  assert.match(validateOrder(rest), /id/);
});

test('rejects a non-positive amount', () => {
  assert.match(validateOrder({ ...validOrder, amount: 0 }), /amount/);
});

test('rejects an empty items array', () => {
  assert.match(validateOrder({ ...validOrder, items: [] }), /items/);
});

test('rejects a non-object body', () => {
  assert.match(validateOrder(null), /object/);
});
