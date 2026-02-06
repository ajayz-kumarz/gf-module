# Grafana Azure AD Module

This Terraform module manages Grafana dashboards on an Azure Managed Grafana instance. It supports recursive folder structures and Azure Entra ID (Azure AD) authentication via the provider configuration.

## Features

- **Recursive Folder Mapping**: Creates Grafana Folders based on the directory structure of your JSON files (e.g., `Team-A/Service-B/dash.json` -> Folder "Team-A/Service-B").
- **Dashboard Import**: detailed support for importing JSON dashboards.
- **Provider Agnostic**: The module logic focuses on resources, allowing you to configure the provider (Azure AD, API Key, etc.) at the root level.

## Prerequisites

- Terraform >= 1.3.0
- Azure CLI (`az`) installed and logged in (`az login`).
- **Grafana Admin** role on the Azure Managed Grafana resource.

## Usage

### 1. Directory Setup
Organize your dashboard JSON files:

```text
my-terraform-project/
├── main.tf
└── dashboards/
    ├── General-Overview.json
    ├── Team-A/
    │   └── App-Metrics.json
    └── Team-B/
        └── Ops/
            └── DB-Stats.json
```

### 2. Terraform Configuration (`main.tf`)

You must configure the `grafana` provider with the Azure AD token.

```hcl
terraform {
  required_providers {
    grafana = { source = "grafana/grafana" }
    azurerm = { source = "hashicorp/azurerm" }
    external = { source = "hashicorp/external" }
  }
}

provider "azurerm" {
  features {}
}

# --- Authentication Logic ---
# Get Azure AD Token for Grafana
data "external" "grafana_token" {
  program = ["bash", "-c", "az account get-access-token --resource https://grafana.azure.com/ --query '{token:accessToken}' -o json"]
}

provider "grafana" {
  url  = "https://<your-instance>.grafana.azure.com/"
  auth = data.external.grafana_token.result.token
}
# ----------------------------

module "grafana_dashboards" {
  source = "./path/to/grafana-module"

  grafana_url    = "https://<your-instance>.grafana.azure.com/"
  dashboards_dir = "${path.module}/dashboards"
}
```

## Importing Existing Dashboards

To bring existing Grafana resources under Terraform management:

1.  **Match the File**: Save the dashboard JSON to your local `dashboards` directory in the correct subfolder.
2.  **Get UID**: Find the dashboard UID from the Grafana URL or JSON.
3.  **Import**:

    **Folder Import:**
    If the folder already exists in Grafana, you must import it too to avoid conflicts.
    ```bash
    # Root level folder
    terraform import 'module.grafana_dashboards.grafana_folder.folders["Team-A"]' existing-folder-uid

    # Nested subfolder
    terraform import 'module.grafana_dashboards.grafana_folder.folders["Team-B/Ops"]' existing-subfolder-uid
    ```

    **Dashboard Import:**
    ```bash
    # Dashboard in a subfolder
    # Format: module.<module_name>.grafana_dashboard.dashboards["<relative_path_to_file>"] <uid>
    terraform import 'module.grafana_dashboards.grafana_dashboard.dashboards["Team-B/Ops/db-stats.json"]' existing-uid-456
    ```