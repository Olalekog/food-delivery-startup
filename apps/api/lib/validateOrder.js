// Pure validation, kept separate from server.js so it's testable without live Azure clients.
function validateOrder(body) {
  if (!body || typeof body !== 'object') {
    return 'Request body must be a JSON object';
  }
  const { id, city, customerName, amount, items } = body;

  if (typeof id !== 'string' || id.trim() === '') {
    return '"id" is required and must be a non-empty string';
  }
  if (typeof city !== 'string' || city.trim() === '') {
    return '"city" is required and must be a non-empty string';
  }
  if (typeof customerName !== 'string' || customerName.trim() === '') {
    return '"customerName" is required and must be a non-empty string';
  }
  if (typeof amount !== 'number' || !Number.isFinite(amount) || amount <= 0) {
    return '"amount" is required and must be a positive number';
  }
  if (!Array.isArray(items) || items.length === 0) {
    return '"items" is required and must be a non-empty array';
  }

  return null;
}

module.exports = { validateOrder };
