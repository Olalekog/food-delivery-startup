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
      node_version = "24"
    }
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME       = "node"
    FUNCTIONS_EXTENSION_VERSION    = "~4"
    AzureWebJobsFeatureFlags       = "EnableWorkerIndexing"
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    # Forces traditional Kudu zip-extraction deployment instead of Run-From-Package. Confirmed
    # across many real applies+deploys that under WEBSITE_RUN_FROM_PACKAGE=1 (the default this
    # ended up with), /home/site/wwwroot only ever contained host.json - package.json, src/, and
    # node_modules never landed, so the host indexed zero functions no matter what the deployed
    # zip contained. This value only takes effect on the resource's initial creation - see
    # ignore_changes below - so it's also applied once directly via `az functionapp config
    # appsettings set` to fix the already-existing app; this declaration documents the intent and
    # covers a from-scratch recreate.
    WEBSITE_RUN_FROM_PACKAGE = "0"
  }

  lifecycle {
    # Confirmed on real applies: this resource showed "Modifying..." on every single apply, and
    # a debug check against the real host (see git history) found functionKeys and systemKeys
    # both completely empty despite masterKey existing - i.e. the Functions host had never
    # finished starting up. app_settings being the plain source of truth here meant every
    # terraform apply reset it back to only these 4 keys, silently wiping out whatever
    # AzureFunctionApp@2 (function-release.yml) added during code deployment (e.g.
    # WEBSITE_RUN_FROM_PACKAGE) - undoing the deployment on every infra apply and leaving the
    # host stuck. Same category of fix as web_app.tf's ignore_changes, just for the whole map
    # since nothing here needs to change post-creation.
    ignore_changes = [app_settings]
  }
}

# A fixed-duration time_sleep here (even with replace_triggered_by re-arming it on every function
# app change) still only guards Terraform-visible restarts. It does nothing when the host restarts
# for a reason Terraform doesn't see - e.g. function-release.yml redeploying code out-of-band right
# before an unrelated `terraform apply` - and a 30s guess was already confirmed too short once
# (functionKeys/systemKeys came back empty despite masterKey existing). Polling until the actual
# system key is non-empty removes the guesswork: it waits exactly as long as the host needs,
# whether that's 5s or 5m.
#
# blobs_extension only ever appears once an EventGrid-sourced blob trigger is actually indexed -
# never on a function app with no code deployed. That happens for real, not just hypothetically:
# an azurerm provider bump (3.x -> 4.x) once forced this exact resource to be replaced, which wiped
# its deployed code, and foodfast-function-release only auto-fires off foodfast-function-build
# completing - never off infra-deploy - so nothing re-deployed the code afterward. Below, before
# polling for the key, self-heal that case by triggering foodfast-function-release directly via the
# Azure DevOps REST API (using the job's own System.AccessToken - see infra-deploy.yml's Apply
# stage, which passes it in as $SYSTEM_ACCESSTOKEN - so no separate PAT/secret is needed) and
# waiting for it to finish, instead of leaving a human to notice and re-run it by hand. This needs
# the project's Build Service identity to have "Queue builds" allowed on foodfast-function-release
# (open the pipeline > (...) > Security) - confirmed NOT granted by default on training-proj
# (TF215106 access denied on a real run) - see DEPLOY.md's one-time setup for the fix; this
# provisioner fails loudly with that same error if it's ever missing again.
#
# triggers uses timestamp(), not the function app id, deliberately - this must re-run and re-check
# on every apply, not just on function app creation/replacement, because the out-of-band restart
# it's guarding against (function-release.yml) never changes anything Terraform can see on the
# function app resource itself.
resource "null_resource" "wait_for_function_keys" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      function_app_name="${azurerm_linux_function_app.orders.name}"
      resource_group="${data.azurerm_resource_group.main.name}"

      indexed=$(az functionapp function list \
        --name "$function_app_name" \
        --resource-group "$resource_group" \
        --query "[].name" -o tsv 2>/dev/null || true)

      if [ -z "$indexed" ]; then
        if [ -z "$${SYSTEM_ACCESSTOKEN:-}" ]; then
          echo "No functions indexed on $function_app_name, and SYSTEM_ACCESSTOKEN isn't set - cannot auto-trigger foodfast-function-release. Run it manually." >&2
          exit 1
        fi

        echo "No functions indexed on $function_app_name - triggering foodfast-function-release to redeploy before waiting for the blobs_extension key."

        export AZURE_DEVOPS_EXT_PAT="$SYSTEM_ACCESSTOKEN"
        devops_org="https://dev.azure.com/324DSTraining"
        devops_project="training-proj"

        run_id=$(az pipelines run --name foodfast-function-release \
          --organization "$devops_org" --project "$devops_project" --detect false \
          --query id -o tsv)
        echo "Triggered foodfast-function-release run $run_id, waiting for it to complete..."

        for i in $(seq 1 60); do
          status=$(az pipelines runs show --id "$run_id" \
            --organization "$devops_org" --project "$devops_project" --detect false \
            --query status -o tsv)
          if [ "$status" = "completed" ]; then
            result=$(az pipelines runs show --id "$run_id" \
              --organization "$devops_org" --project "$devops_project" --detect false \
              --query result -o tsv)
            if [ "$result" != "succeeded" ]; then
              echo "foodfast-function-release run $run_id finished with result '$result', not 'succeeded'" >&2
              exit 1
            fi
            echo "foodfast-function-release run $run_id succeeded"
            break
          fi
          echo "foodfast-function-release run $run_id still $status (attempt $i/60)..."
          sleep 10
        done
      fi

      for i in $(seq 1 30); do
        key=$(az functionapp keys list \
          --name "$function_app_name" \
          --resource-group "$resource_group" \
          --query "systemKeys.blobs_extension" -o tsv 2>/dev/null || true)
        if [ -n "$key" ] && [ "$key" != "None" ]; then
          echo "blobs_extension system key is ready"
          exit 0
        fi
        echo "Waiting for blobs_extension system key to become available (attempt $i/30)..."
        sleep 10
      done
      echo "Timed out waiting for blobs_extension system key to become available." >&2
      echo "This key only exists once the host has an EventGrid-sourced blob trigger indexed." >&2
      echo "It never appears on a function app with no code deployed - check:" >&2
      echo "  az functionapp function list --name $function_app_name --resource-group $resource_group" >&2
      echo "If that returns [], manually run the foodfast-function-release pipeline (or its" >&2
      echo "upstream foodfast-function-build) to redeploy blobOrderTrigger, then re-run this apply." >&2
      exit 1
    EOT
  }
}

data "azurerm_function_app_host_keys" "orders" {
  name                = azurerm_linux_function_app.orders.name
  resource_group_name = data.azurerm_resource_group.main.name

  depends_on = [null_resource.wait_for_function_keys]
}
