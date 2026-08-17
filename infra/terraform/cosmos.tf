resource "azurerm_cosmosdb_account" "this" {
  name                = var.cosmos_account_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  tags                = var.tags

  capabilities {
    name = "EnableServerless"
  }

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = data.azurerm_resource_group.main.location
    failover_priority = 0
  }
}

resource "azurerm_cosmosdb_sql_database" "foodfast" {
  name                = "FoodFast"
  resource_group_name = data.azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.this.name
  # No throughput block - serverless accounts reject explicit provisioning.
}

resource "azurerm_cosmosdb_sql_container" "orders" {
  name                  = "Orders"
  resource_group_name   = data.azurerm_resource_group.main.name
  account_name          = azurerm_cosmosdb_account.this.name
  database_name         = azurerm_cosmosdb_sql_database.foodfast.name
  partition_key_paths   = ["/city"]
  partition_key_version = 2
  # No throughput block here either - same serverless restriction.
}

resource "azurerm_key_vault_secret" "cosmos_key" {
  name         = "cosmosPrimaryKey"
  value        = azurerm_cosmosdb_account.this.primary_key
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [time_sleep.wait_for_kv_rbac]
}

resource "azurerm_key_vault_secret" "cosmos_endpoint" {
  name         = "cosmosEndpoint"
  value        = azurerm_cosmosdb_account.this.endpoint
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [time_sleep.wait_for_kv_rbac]
}
