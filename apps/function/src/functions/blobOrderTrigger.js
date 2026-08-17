const { app } = require('@azure/functions');

// source: 'EventGrid' uses the Functions host's Event Grid-based blob trigger (near-instant,
// wired to an Event Grid subscription in Terraform - see infra/terraform/eventgrid.tf), not the
// older polling blob trigger. The function name below must exactly match `blobOrderTrigger` -
// the Event Grid subscription's webhook URL references it as Host.Functions.blobOrderTrigger.
app.storageBlob('blobOrderTrigger', {
  path: 'orders/{name}',
  connection: 'AzureWebJobsStorage',
  source: 'EventGrid',
  handler: (blob, context) => {
    let order;
    try {
      order = JSON.parse(Buffer.from(blob).toString('utf-8'));
    } catch (err) {
      context.error(`Order blob ${context.triggerMetadata?.name} is not valid JSON: ${err.message}`);
      return;
    }
    context.log(`Order amount: ${order.amount}`);
  },
});
