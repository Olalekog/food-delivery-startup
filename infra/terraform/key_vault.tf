# Access Policies, not RBAC authorization - confirmed on a real apply that the AzureTraining SPN
# lacks Microsoft.Authorization/roleAssignments/write on Training-Batch-6.23 (403
# AuthorizationFailed) and that this is a hard constraint on this training subscription, not a
# temporary gap. Access policies avoid that permission entirely: granting one is a property write
# on the vault resource itself (Microsoft.KeyVault/vaults/write), which the SPN already has -
# proven by the vault having been created successfully in the same apply that failed on RBAC.
resource "azurerm_key_vault" "this" {
  name                      = var.key_vault_name
  resource_group_name       = data.azurerm_resource_group.main.name
  location                  = data.azurerm_resource_group.main.location
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  sku_name                  = "standard"
  enable_rbac_authorization = false
  purge_protection_enabled  = false
  tags                      = var.tags
}

resource "azurerm_key_vault_access_policy" "terraform_caller" {
  key_vault_id = azurerm_key_vault.this.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "List", "Set", "Delete", "Purge"]
}
