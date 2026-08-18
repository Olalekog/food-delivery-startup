resource "azurerm_service_plan" "api" {
  name                = "${var.web_app_name}-plan"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "B1"
  tags                = var.tags
}

# Cosmos endpoint/key and the storage connection string are injected as app settings by the
# release pipeline (AzureKeyVault@2 -> AzureWebApp@1 appSettings), not baked in here - see
# pipelines/api-release.yml. No managed identity / RBAC here: the AzureTraining SPN on this
# training subscription has no Microsoft.Authorization/roleAssignments/write rights (confirmed on
# a real apply), so blob access goes through a connection string like the Cosmos key does, not a
# Storage Blob Data Contributor role grant to a system-assigned identity.
resource "azurerm_linux_web_app" "api" {
  name                = var.web_app_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.api.id
  tags                = var.tags

  site_config {
    application_stack {
      node_version = "20-lts"
    }
  }

  app_settings = {
    ORDERS_CONTAINER_NAME          = azurerm_storage_container.orders.name
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
  }

  lifecycle {
    # COSMOS_KEY / COSMOS_ENDPOINT / STORAGE_CONNECTION_STRING are set by the release pipeline on
    # every deploy - don't let Terraform fight it and revert them back to unset on the next apply.
    ignore_changes = [
      app_settings["COSMOS_KEY"],
      app_settings["COSMOS_ENDPOINT"],
      app_settings["STORAGE_CONNECTION_STRING"],
    ]
  }
}
