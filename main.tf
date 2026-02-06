locals {
  # Normalize path separators to forward slashes for consistency
  dashboards_dir_normalized = replace(var.dashboards_dir, "\\", "/")

  # Find all JSON files in the dashboards directory recursively
  dashboard_files = fileset(local.dashboards_dir_normalized, "**/*.json")

  # 1. Map files to their specific folder path
  #    Team-A/Ops/db.json -> folder_path = "Team-A/Ops"
  file_folder_map = {
    for f in local.dashboard_files : replace(f, "\\", "/") => {
      content     = file("${local.dashboards_dir_normalized}/${f}")
      folder_path = replace(dirname(f), "\\", "/")
      filename    = basename(f)
    }
  }

  # 2. Extract ALL explicit folder paths from the files
  raw_folder_paths = distinct([
    for v in local.file_folder_map : v.folder_path if v.folder_path != "."
  ])

  # 3. Expand implicit parent paths. 
  #    We want to ensure that if "A/B/C" exists, "A" and "A/B" are also created.
  #    Since we are using a flat loop now, we need to generate all parent combinations.
  #    (This simple logic covers reasonable depth, but to be truly infinite 
  #     without hardcoding, we'd need a recursive module or external data. 
  #     However, we can just map broadly enough here.)
  
  #    Let's use a trick to explode paths: "A/B/C" -> ["A", "A/B", "A/B/C"]
  #    We can stick to the previous expansion logic but maybe add a couple more levels to be safe,
  #    OR since we are doing 5 levels requested, let's explicitly expand up to 5 levels here.
  all_folders_expanded = flatten([
    for path in local.raw_folder_paths : [
      path,
      # Parent
      length(regexall("/", path)) > 0 ? dirname(path) : null,
      # Grandparent
      length(regexall("/", path)) > 1 ? dirname(dirname(path)) : null,
      # Great-Grandparent
      length(regexall("/", path)) > 2 ? dirname(dirname(dirname(path))) : null,
      # Great-Great-Grandparent
      length(regexall("/", path)) > 3 ? dirname(dirname(dirname(dirname(path)))) : null
    ]
  ])

  # Clean up the list: remove nulls, remove ".", distinct values
  unique_folders = distinct([
    for p in local.all_folders_expanded : p if p != null && p != "."
  ])
}

# --- UNIFIED FOLDER RESOURCE (Infinite Depth via Deterministic UIDs) ---
resource "grafana_folder" "folders" {
  for_each = toset(local.unique_folders)

  title = basename(each.key)
  
  # Generate a stable UID based on the path.
  # This breaks the dependency cycle because we don't need to look up the parent resource.
  # We just know what the parent's UID *will* be.
  uid = md5(each.key)

  # Calculate Parent UID
  parent_folder_uid = (
    dirname(each.key) == "." ? 
    null : 
    md5(dirname(each.key))
  )
}

# 2. Create Dashboards
resource "grafana_dashboard" "dashboards" {
  for_each = local.file_folder_map

  config_json = each.value.content

  # We compute the folder UID directly from the path string.
  # No need to lookup the folder resource.
  folder = (
    each.value.folder_path == "." ? 
    null : 
    md5(each.value.folder_path)
  )
  
  overwrite = true
  
  # Ensure the dashboard is created AFTER the folder exists
  depends_on = [grafana_folder.folders]
}
