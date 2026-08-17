# Consumption-plan Logic App (azurerm_logic_app_workflow's default) - this matters because
# Consumption auto-handles the Event Grid subscription-validation handshake; Logic Apps Standard
# would require handling that handshake in code instead.
resource "azurerm_logic_app_workflow" "orders_notify" {
  name                = var.logic_app_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  tags                = var.tags

  workflow_parameters = {
    "$connections" = jsonencode({ defaultValue = {}, type = "Object" })
  }

  parameters = {
    "$connections" = jsonencode({
      office365 = {
        connectionId   = azurerm_api_connection.office365.id
        connectionName = "office365"
        id             = data.azurerm_managed_api.office365.id
      }
    })
  }
}

data "azurerm_managed_api" "office365" {
  name     = "office365"
  location = data.azurerm_resource_group.main.location
}

# Terraform can only create the connection *shell* - it cannot supply OAuth2 consent. After the
# first apply, this must be authorized once in the Azure Portal (Edit API connection > Authorize
# > sign in > Save) before the Logic App action below can actually send mail. See DEPLOY.md.
resource "azurerm_api_connection" "office365" {
  name                = "office365"
  resource_group_name = data.azurerm_resource_group.main.name
  managed_api_id      = data.azurerm_managed_api.office365.id
  display_name        = "FoodFast Ops Notifications"
}

resource "azurerm_logic_app_trigger_http_request" "blob_event" {
  name         = "when-blob-event-received"
  logic_app_id = azurerm_logic_app_workflow.orders_notify.id
  schema       = "{}"
}

# Event Grid always delivers max_events_per_batch=1 as a single-element array (see
# eventgrid.tf's orders_blob_to_logicapp subscription), so triggerBody()?[0] is safe here.
# `subject` looks like "/blobServices/default/containers/orders/blobs/<name>.json" - both the
# .json check and the filename (via split on '/') come from that one field.
#
# NOTE: the Office 365 "Send an email (V2)" action body below is a best-effort shape based on the
# connector's documented ApiConnection JSON. Per DEPLOY.md step 4, build this one action for real
# in the Portal Designer once the connection is authorized, switch to Code View, and replace this
# body with the exact generated JSON - connector operation schemas aren't fully pinned by docs
# alone.
resource "azurerm_logic_app_action_custom" "is_json" {
  name         = "Condition-Is-JSON"
  logic_app_id = azurerm_logic_app_workflow.orders_notify.id

  body = jsonencode({
    type = "If"
    expression = {
      "and" = [
        {
          endsWith = ["@triggerBody()?[0]?['subject']", ".json"]
        }
      ]
    }
    actions = {
      Send_an_email_V2 = {
        type = "ApiConnection"
        inputs = {
          host = {
            connection = {
              name = "@parameters('$connections')['office365']['connectionId']"
            }
          }
          method = "post"
          path   = "/v2/Mail"
          body = {
            To      = var.ops_notification_email
            Subject = "New order received"
            Body    = "New order file: @{last(split(triggerBody()?[0]?['subject'], '/'))}"
          }
        }
        runAfter = {}
      }
    }
    else = {
      actions = {}
    }
  })

  depends_on = [azurerm_logic_app_trigger_http_request.blob_event]
}
