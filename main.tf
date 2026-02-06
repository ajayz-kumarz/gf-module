locals {
  # Normalize path separators to forward slashes for consistency
  # This ensures that even if a Windows path with backslashes is provided, we use forward slashes internally.
  dashboards_dir_normalized = replace(var.dashboards_dir, "\\", "/")

  # Find all JSON files in the dashboards directory recursively
  dashboard_files = fileset(local.dashboards_dir_normalized, "**/*.json")

  # Extract unique directory paths from the file list to create folders.
  # If a file is at "team-a/service-b/dash.json", the folder path is "team-a/service-b".
  # If a file is at root "dash.json", the folder path is "." which we map to General or ignore.
  
  # Map: { "relative_file_path" = { content = "...", folder_path = "..." } }
  dashboards_map = {
    for f in local.dashboard_files : replace(f, "\\", "/") => {
      content     = file("${local.dashboards_dir_normalized}/${f}")
      folder_path = replace(dirname(f), "\\", "/")
      filename    = basename(f)
      # Create a stable slug/ID from the filename or content if needed
      slug        = replace(basename(f), ".json", "")
    }
  }

  # Identify unique folder paths (excluding root ".")
  folder_paths = distinct([
    for v in local.dashboards_map : v.folder_path if v.folder_path != "."
  ])
}

# 1. Create Grafana Folders based on the directory structure
resource "grafana_folder" "folders" {
  for_each = toset(local.folder_paths)

  # Title will be the directory path. 
  # Note: Grafana folders are traditionally flat. 
  # If you have "A/B", this will create a folder named "A/B".
  # To support true nested folders (Grafana 11+ feature), you'd need more complex logic 
  # creating parent then child. For compatibility, we use the path as the name.
  title = each.key
}

# 2. Create Dashboards
resource "grafana_dashboard" "dashboards" {
  for_each = local.dashboards_map

  config_json = each.value.content

  # If the file is in the root, folder is null (General folder).
  # Otherwise, look up the folder UID from the created folders.
  folder = each.value.folder_path == "." ? null : grafana_folder.folders[each.value.folder_path].uid
  
  # Optional: overwrite behavior
  overwrite = true
}
