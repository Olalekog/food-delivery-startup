# EP1 (Elastic Premium), not Y1 (Consumption) - confirmed on a real apply that
# Training-Batch-6.23 rejects Y1 ("Requested features 'Dynamic SKU, Linux Worker' not
# available in resource group"). Flex Consumption (azurerm_function_app_flex_consumption)
# would avoid EP1's fixed cost, but that resource type only exists in azurerm provider ~>4.x -
# confirmed via a local schema check that it's absent from our pinned ~>3.116 - and bumping the
# whole provider major version was judged too risky/out of scope here.
resource "azurerm_service_plan" "functions" {
  name                = "${var.function_app_name}-plan"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "EP1"
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

# blobs_extension_key is a platform-level system key - reading it right after the app is created
# OR modified can race the app's (re)provisioning. replace_triggered_by is required, not just
# depends_on: confirmed on a real apply that time_sleep only sleeps once, at its own creation - on
# a later apply where the function app is merely *modified* (e.g. app_settings change forcing a
# restart), the already-existing time_sleep does NOT re-sleep, so the host-keys data source below
# got read 1 second after a 1m15s app restart instead of waiting for it, producing an invalid key
# and a 401 on the Event Grid webhook validation (eventgrid.tf). replace_triggered_by forces this
# resource to be replaced - and therefore sleep again - on every change to the function app, not
# just its first creation.
resource "time_sleep" "wait_for_function_app" {
  depends_on      = [azurerm_linux_function_app.orders]
  create_duration = "30s"

  lifecycle {
    replace_triggered_by = [azurerm_linux_function_app.orders]
  }
}

data "azurerm_function_app_host_keys" "orders" {
  name                = azurerm_linux_function_app.orders.name
  resource_group_name = data.azurerm_resource_group.main.name

  depends_on = [time_sleep.wait_for_function_app]
}
