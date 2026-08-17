data "azurerm_resource_group" "main" {
  name = var.existing_resource_group_name
}

resource "azurerm_storage_account" "this" {
  name                     = var.storage_account_name
  resource_group_name      = data.azurerm_resource_group.main.name
  location                 = data.azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags
}

resource "azurerm_storage_container" "orders" {
  name                  = "orders"
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = "private"
}
