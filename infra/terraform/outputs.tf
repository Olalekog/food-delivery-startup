output "web_app_url" {
  value = "https://${azurerm_linux_web_app.api.default_hostname}"
}

output "web_app_name" {
  value = azurerm_linux_web_app.api.name
}

output "function_app_name" {
  value = azurerm_linux_function_app.orders.name
}

output "storage_account_name" {
  value = azurerm_storage_account.this.name
}

output "cosmos_endpoint" {
  value = azurerm_cosmosdb_account.this.endpoint
}

output "key_vault_name" {
  value = azurerm_key_vault.this.name
}
