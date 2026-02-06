# Grafana Azure AD Module

This Terraform module manages Grafana dashboards on an Azure Managed Grafana instance. It supports recursive folder structures, cross-platform path handling, and Azure Entra ID (Azure AD) authentication.

## Features

- **Nested Folder Support**: Automatically creates Grafana folders based on your directory structure (supports up to **5 levels** of nesting).
- **Cross-Platform Compatibility**: Handles path separators correctly on both **Windows** (backslashes) and **Linux/macOS** (forward slashes).
- **Dashboard Import**: Seamlessly imports JSON dashboards into their respective folders.
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
# NOTE for Windows: You may need to use ["powershell", "-Command", "..."] 
# if 'bash' is not available.
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

To bring existing Grafana resources under Terraform management, you must import them into the correct level resource.

### 1. Match the File
Save the dashboard JSON to your local `dashboards` directory in the correct subfolder.

### 2. Import Folders
Folders are split into levels (`l1` to `l5`) based on their depth.

```bash
# Level 1 (Root folder)
terraform import 'module.grafana_dashboards.grafana_folder.folders_l1["Team-A"]' <uid>

# Level 2 (Subfolder)
terraform import 'module.grafana_dashboards.grafana_folder.folders_l2["Team-A/Ops"]' <uid>

# Level 3 (Sub-subfolder)
terraform import 'module.grafana_dashboards.grafana_folder.folders_l3["Team-A/Ops/Prod"]' <uid>
```

### 3. Import Dashboards
Use the relative path from your dashboards directory as the key.

```bash
# Dashboard in a subfolder
terraform import 'module.grafana_dashboards.grafana_dashboard.dashboards["Team-A/Ops/app-metrics.json"]' <uid>
```

*Note: Always use forward slashes (`/`) in the Terraform keys, even on Windows.*
