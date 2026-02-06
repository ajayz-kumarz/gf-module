locals {
  # Normalize path separators to forward slashes for consistency
  dashboards_dir_normalized = replace(var.dashboards_dir, "\\", "/")

  # Find all JSON files in the dashboards directory recursively
  dashboard_files = fileset(local.dashboards_dir_normalized, "**/*.json")

  # 1. Map files to their specific folder path
  #    Team-A/Ops/db.json -> folder_path = "Team-A/Ops"
  file_folder_map = {
    for f in local.dashboard_files : replace(f, "\\", "/") => {
      # Read and parse the JSON
      json_content = jsondecode(file("${local.dashboards_dir_normalized}/${f}"))
      
      # Sanitize: Remove fields that cause drift or are managed by Grafana/Terraform
      # - id: Managed by Grafana (internal database ID).
      # - version: Managed by Grafana (optimistic locking).
      # - uid: MUST be preserved so Grafana knows which dashboard to update.
      # Note: We keep 'time' because removing it causes perpetual drift (Grafana adds it back).
      content = jsonencode({
        for k, v in jsondecode(file("${local.dashboards_dir_normalized}/${f}")) : 
        k => v if !contains(["id", "version"], k)
      })

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
  #    We expand up to 5 levels.
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

  # 4. Split by depth for Terraform sequencing (Level 1 = Root, Level 2 = Nested, etc.)
  #    Level 1: "Team-A" (0 slashes)
  folders_l1 = toset([for p in local.unique_folders : p if length(regexall("/", p)) == 0])
  
  #    Level 2: "Team-A/Ops" (1 slash)
  folders_l2 = toset([for p in local.unique_folders : p if length(regexall("/", p)) == 1])

  #    Level 3: "Team-A/Ops/Deploys" (2 slashes)
  folders_l3 = toset([for p in local.unique_folders : p if length(regexall("/", p)) == 2])

  #    Level 4: "Team-A/Ops/Deploys/Prod" (3 slashes)
  folders_l4 = toset([for p in local.unique_folders : p if length(regexall("/", p)) == 3])

  #    Level 5: "Team-A/Ops/Deploys/Prod/East" (4 slashes)
  folders_l5 = toset([for p in local.unique_folders : p if length(regexall("/", p)) == 4])
}

# --- LEVEL 1 FOLDERS (ROOT) ---
resource "grafana_folder" "folders_l1" {
  for_each = local.folders_l1
  title    = each.key
}

# --- LEVEL 2 FOLDERS ---
resource "grafana_folder" "folders_l2" {
  for_each = local.folders_l2
  title             = basename(each.key)
  parent_folder_uid = grafana_folder.folders_l1[dirname(each.key)].uid
}

# --- LEVEL 3 FOLDERS ---
resource "grafana_folder" "folders_l3" {
  for_each = local.folders_l3
  title             = basename(each.key)
  parent_folder_uid = grafana_folder.folders_l2[dirname(each.key)].uid
}

# --- LEVEL 4 FOLDERS ---
resource "grafana_folder" "folders_l4" {
  for_each = local.folders_l4
  title             = basename(each.key)
  parent_folder_uid = grafana_folder.folders_l3[dirname(each.key)].uid
}

# --- LEVEL 5 FOLDERS ---
resource "grafana_folder" "folders_l5" {
  for_each = local.folders_l5
  title             = basename(each.key)
  parent_folder_uid = grafana_folder.folders_l4[dirname(each.key)].uid
}

# 2. Create Dashboards
resource "grafana_dashboard" "dashboards" {
  for_each = local.file_folder_map

  config_json = each.value.content

  # Determine which folder resource to look up.
  # We check the depth of the folder_path to decide which map to access.
  folder = (
    each.value.folder_path == "." ? null :
    contains(local.folders_l5, each.value.folder_path) ? grafana_folder.folders_l5[each.value.folder_path].uid :
    contains(local.folders_l4, each.value.folder_path) ? grafana_folder.folders_l4[each.value.folder_path].uid :
    contains(local.folders_l3, each.value.folder_path) ? grafana_folder.folders_l3[each.value.folder_path].uid :
    contains(local.folders_l2, each.value.folder_path) ? grafana_folder.folders_l2[each.value.folder_path].uid :
    contains(local.folders_l1, each.value.folder_path) ? grafana_folder.folders_l1[each.value.folder_path].uid :
    null
  )
  
  overwrite = true
}
