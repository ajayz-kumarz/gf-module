terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"
    }
    grafana = {
      source  = "grafana/grafana"
      version = ">= 2.9.0"
    }
    external = {
      source = "hashicorp/external"
      version = ">= 2.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# --- Azure AD Authentication for Grafana ---
# Fetch the access token for the Grafana Resource ID
# NOTE: This example uses 'bash' which works on Linux/macOS. 
# For Windows, you may need to use ["powershell", "-Command", "..."] or ["cmd", "/C", "az ..."]
# or ensure you have a bash environment available.
data "external" "grafana_token" {
  program = ["bash", "-c", "az account get-access-token --resource https://grafana.azure.com/ --query '{token:accessToken}' -o json"]
}

provider "grafana" {
  url  = "https://example-grafana.grafana.azure.com/" # Replace with your actual Grafana URL
  auth = data.external.grafana_token.result.token
}
# -------------------------------------------

module "grafana_dashboards" {
  source = "../../"

  # We pass variables that the module expects
  # The 'grafana_url' variable inside the module is actually not needed for the resources 
  # if the provider is configured at the root, but I kept it in variables.tf. 
  # Let's check variables.tf... It has 'grafana_url'.
  # I'll pass it, though strictly speaking the provider handles the connection.
  grafana_url    = "https://example-grafana.grafana.azure.com/"
  dashboards_dir = "${path.module}/dashboards"
}