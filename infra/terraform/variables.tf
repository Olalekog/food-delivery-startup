variable "existing_resource_group_name" {
  description = "Name of the existing, shared resource group to deploy into"
  type        = string
  default     = "Training-Batch-6.23"
}

variable "storage_account_name" {
  description = "Globally-unique name for the storage account (lowercase alphanumeric, <=24 chars)"
  type        = string
  default     = "stfoodfastogogu"
}

variable "key_vault_name" {
  description = "Globally-unique name for the Key Vault"
  type        = string
  default     = "kv-foodfast-ogogundare"
}

variable "cosmos_account_name" {
  description = "Globally-unique name for the Cosmos DB account"
  type        = string
  default     = "cosmos-foodfast-ogogundare"
}

variable "web_app_name" {
  description = "Globally-unique name for the API's Linux Web App"
  type        = string
  default     = "foodfast-api-ogogundare"
}

variable "function_app_name" {
  description = "Globally-unique name for the Function App"
  type        = string
  default     = "foodfast-orders-fn-ogogundare"
}

variable "logic_app_name" {
  description = "Name for the order-notification Logic App"
  type        = string
  default     = "foodfast-order-email"
}

variable "ops_notification_email" {
  description = "Recipient address for the 'New order received' Logic App email"
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    project = "foodfast"
  }
}
