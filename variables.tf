variable "grafana_url" {
  description = "The URL of the Azure Managed Grafana instance (e.g., https://<name>.grafana.azure.com/)"
  type        = string
}

variable "dashboards_dir" {
  description = "Path to the local directory containing Grafana dashboard JSON files."
  type        = string
}

variable "subscription_id" {
  description = "Azure Subscription ID where the Managed Grafana instance resides (optional if authenticated via CLI default)."
  type        = string
  default     = null
}
