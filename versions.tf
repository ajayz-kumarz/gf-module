terraform {
  required_version = ">= 1.3.0"

  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = ">= 2.9.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"
    }
    external = {
      source = "hashicorp/external"
      version = ">= 2.0.0"
    }
  }
}
