resource "azurerm_key_vault" "this" {
  name                      = var.key_vault_name
  resource_group_name       = data.azurerm_resource_group.main.name
  location                  = data.azurerm_resource_group.main.location
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  sku_name                  = "standard"
  enable_rbac_authorization = true
  purge_protection_enabled  = false
  tags                      = var.tags
}

# Under RBAC authorization, creating the vault grants the caller no data-plane access - without
# this, the secret writes below fail with 403.
resource "azurerm_role_assignment" "terraform_caller_kv_secrets_officer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Role assignments can take up to a minute or two to actually be enforced - without this pause,
# the secret writes below can still 403 even though the assignment above already "succeeded".
resource "time_sleep" "wait_for_kv_rbac" {
  depends_on      = [azurerm_role_assignment.terraform_caller_kv_secrets_officer]
  create_duration = "30s"
}
