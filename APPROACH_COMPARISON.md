# Grafana Folder Management: Approach Comparison

This document compares two strategies for managing nested Grafana folders in Terraform: the **Deterministic UID** approach and the **Level-Based** approach.

## Comparison Table

| Feature | **Deterministic UID (MD5)** | **Level-Based (L1-L5)** |
| :--- | :--- | :--- |
| **Primary Mechanism** | Folder UIDs are forced to match `md5(folder_path)`. | Folder UIDs are randomly assigned by Grafana (or preserved). |
| **Nesting Depth** | **Unlimited** (Infinite). | Limited to explicit levels (currently **5**). |
| **Dependency Cycles** | **Eliminated** by computing parent UIDs from strings. | Managed by separate resources (`l1` → `l2` → `l3`). |
| **Importing Existing Resources** | **Disruptive**. Forces existing folders to change their UIDs to the new MD5 hash. | **Seamless**. Respects and preserves existing UIDs found in Grafana. |
| **Existing Dashboard Links** | **Breaks Links**. If folder/dashboard UIDs change, bookmarked URLs will 404. | **Safe**. Links remain valid as UIDs do not change. |
| **Code Simplicity** | High. Single resource block handles everything. | Medium. Requires repeated blocks for each level (`folders_l1`, `folders_l2`...). |
| **Terraform Plan Output** | Clean, but always shows "uid will change" on first run. | Clean, shows "no changes" if state matches reality. |
| **Best Use Case** | **Greenfield Projects**. New setups where you want total control and reproducibility. | **Brownfield Projects**. Importing existing Grafana instances where preserving history/links is critical. |

## Why Level-Based?

We chose the **Level-Based (L1-L5)** approach for this module because:

1.  **Import Stability**: It allows users to `terraform import` existing Grafana folders without Terraform forcing a UID change.
2.  **Safety**: It prevents breaking existing bookmarks or external links that rely on current UIDs.
3.  **Flexibility**: While limited to 5 levels, this covers the vast majority of organizational needs.
