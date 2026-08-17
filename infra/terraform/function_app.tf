resource "azurerm_service_plan" "functions" {
  name                = "${var.function_app_name}-plan"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "Y1"
  tags                = var.tags
}

resource "azurerm_linux_function_app" "orders" {
  name                       = var.function_app_name
  resource_group_name        = data.azurerm_resource_group.main.name
  location                   = data.azurerm_resource_group.main.location
  service_plan_id            = azurerm_service_plan.functions.id
  storage_account_name       = azurerm_storage_account.this.name
  storage_account_access_key = azurerm_storage_account.this.primary_access_key
  tags                       = var.tags

  site_config {
    application_stack {
      node_version = "20"
    }
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME       = "node"
    FUNCTIONS_EXTENSION_VERSION    = "~4"
    AzureWebJobsFeatureFlags       = "EnableWorkerIndexing"
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
  }
}

# blobs_extension_key is a platform-level system key that exists as soon as the Function App
# resource does, independent of whether code has been deployed to it yet - but reading it right
# after creation can occasionally race the app's provisioning, so wait like the KV RBAC grant does.
resource "time_sleep" "wait_for_function_app" {
  depends_on      = [azurerm_linux_function_app.orders]
  create_duration = "30s"
}

data "azurerm_function_app_host_keys" "orders" {
  name                = azurerm_linux_function_app.orders.name
  resource_group_name = data.azurerm_resource_group.main.name

  depends_on = [time_sleep.wait_for_function_app]
}
