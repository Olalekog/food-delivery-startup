resource "azurerm_service_plan" "api" {
  name                = "${var.web_app_name}-plan"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "B1"
  tags                = var.tags
}

# Cosmos endpoint/key are injected as app settings by the release pipeline (AzureKeyVault@2 ->
# AzureWebApp@1 appSettings), not baked in here - see pipelines/api-release.yml.
resource "azurerm_linux_web_app" "api" {
  name                = var.web_app_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.api.id
  tags                = var.tags

  # System-assigned identity lets the API write blobs via @azure/identity's
  # DefaultAzureCredential instead of handling a storage key at all.
  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      node_version = "20-lts"
    }
  }

  app_settings = {
    STORAGE_ACCOUNT_NAME           = azurerm_storage_account.this.name
    ORDERS_CONTAINER_NAME          = azurerm_storage_container.orders.name
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
  }

  lifecycle {
    # COSMOS_KEY / COSMOS_ENDPOINT are set by the release pipeline on every deploy - don't let
    # Terraform fight it and revert them back to unset on the next apply.
    ignore_changes = [app_settings["COSMOS_KEY"], app_settings["COSMOS_ENDPOINT"]]
  }
}

resource "azurerm_role_assignment" "web_app_storage_blob_contributor" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_web_app.api.identity[0].principal_id
}
