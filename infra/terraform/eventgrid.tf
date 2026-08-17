resource "azurerm_eventgrid_system_topic" "storage" {
  name                   = "foodfast-storage-topic"
  resource_group_name    = data.azurerm_resource_group.main.name
  location               = data.azurerm_resource_group.main.location
  source_arm_resource_id = azurerm_storage_account.this.id
  topic_type             = "Microsoft.Storage.StorageAccounts"
  tags                   = var.tags
}

# Blob-trigger-with-source=EventGrid (the Node v4 `app.storageBlob({source:'EventGrid'})` model)
# uses the Functions host's fixed /runtime/webhooks/blobs route, not a native eventGridTrigger
# binding - so this is a webhook_endpoint subscription, not azure_function_endpoint/function_id.
resource "azurerm_eventgrid_system_topic_event_subscription" "orders_blob_to_function" {
  name                  = "orders-blob-to-function"
  system_topic          = azurerm_eventgrid_system_topic.storage.name
  resource_group_name   = data.azurerm_resource_group.main.name
  event_delivery_schema = "EventGridSchema"
  included_event_types  = ["Microsoft.Storage.BlobCreated"]

  subject_filter {
    subject_begins_with = "/blobServices/default/containers/orders/blobs/"
  }

  webhook_endpoint {
    url                               = "https://${azurerm_linux_function_app.orders.default_hostname}/runtime/webhooks/blobs?functionName=Host.Functions.blobOrderTrigger&code=${data.azurerm_function_app_host_keys.orders.blobs_extension_key}"
    max_events_per_batch              = 1
    preferred_batch_size_in_kilobytes = 64
  }
}

# Both subscriptions independently fan out from the same event - no exclusivity constraint - so
# the Function App and the Logic App each get their own subscription to the same blob-created
# events. Neither has a suffix filter for .json: the Function App only cares about amount logging
# (any blob), and the Logic App's own Condition step (not Event Grid) is what restricts email to
# .json files, per the spec.
resource "azurerm_eventgrid_system_topic_event_subscription" "orders_blob_to_logicapp" {
  name                  = "orders-blob-to-logicapp"
  system_topic          = azurerm_eventgrid_system_topic.storage.name
  resource_group_name   = data.azurerm_resource_group.main.name
  event_delivery_schema = "EventGridSchema"
  included_event_types  = ["Microsoft.Storage.BlobCreated"]

  subject_filter {
    subject_begins_with = "/blobServices/default/containers/orders/blobs/"
  }

  webhook_endpoint {
    url                  = azurerm_logic_app_trigger_http_request.blob_event.callback_url
    max_events_per_batch = 1
  }
}
