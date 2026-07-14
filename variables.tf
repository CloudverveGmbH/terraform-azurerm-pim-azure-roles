# ---------------------------------------------------------------------------
# Module: pim-azure-role
# Purpose: Creates a two-group PIM setup (Eligible + Privileged) for Azure RBAC.
#          Members of the Eligible group activate into the Privileged group via PIM.
#
# Usage pattern:
#   module "my_role_pim" {
#     source             = "./modules/pim-azure-role"
#     group_display_name = "AKS Cluster Admin"
#     members            = [{ object_id = data.azuread_user.alice.object_id }]
#     role_assignments   = [{ scope = azurerm_kubernetes_cluster.aks.id, role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin" }]
#   }
#
# Circular-dependency note:
#   When the role assignment scope depends on a resource that in turn references
#   the group (e.g. AKS admin_group_object_ids), set role_assignments = []
#   and create the azurerm_role_assignment externally.
# ---------------------------------------------------------------------------

variable "group_display_name" {
  description = "Base display name. Two groups are created: 'pim-<slug>-eligible' and 'pim-<slug>'."
  type        = string

  validation {
    condition     = length(trimspace(var.group_display_name)) > 0
    error_message = "group_display_name must not be empty."
  }

  validation {
    # The slug is derived from lowercased alphanumeric runs. Reject names that
    # contain no usable characters (e.g. "---") because they produce an empty slug.
    condition     = length(join("-", regexall("[a-z0-9]+", lower(var.group_display_name)))) > 0
    error_message = "group_display_name must contain at least one alphanumeric character."
  }
}

variable "group_owners" {
  description = <<-EOT
    Additional owner object IDs for both groups (users or SPNs).
    The Terraform principal (data.azuread_client_config.current) is always
    added as an owner automatically so the groups remain manageable.
  EOT
  type        = list(string)
  default     = []
}

variable "members" {
  description = <<-EOT
    Entra ID objects to add as permanent members of the Eligible group via Terraform.
    Leave empty ([]) to manage group membership outside Terraform (recommended for
    large teams – avoids a terraform apply per joiner/leaver).
  EOT
  type = list(object({
    object_id    = string
    display_name = optional(string, "")
  }))
  default = []
}

variable "approvers" {
  description = <<-EOT
    PIM approvers. When set, activations require both approval and a business justification.
    Leave empty ([]) to allow self-activation without approval.
    Each entry:
      object_id = "<uuid>"                        # user or group object_id
      type      = "singleUser" | "groupMembers"   # optional - auto-inferred from Entra if omitted
    Examples:
      # Type inferred automatically (user or group, Entra decides):
      approvers = [{ object_id = data.azuread_user.joscha.object_id }]
      approvers = [{ object_id = azuread_group.managers.object_id }]
      # Explicit type override:
      approvers = [{ object_id = "...", type = "groupMembers" }]
  EOT
  type = list(object({
    object_id = string
    type      = optional(string) # null = auto-infer from Entra directory object type
  }))
  default = []

  validation {
    condition = alltrue([
      for a in var.approvers : a.type == null || contains(["singleUser", "groupMembers"], a.type)
    ])
    error_message = "approvers[].type must be null (auto-infer), \"singleUser\", or \"groupMembers\"."
  }
}

variable "require_justification" {
  description = "Require a business justification on activation. Independent of approval."
  type        = bool
  default     = true
}

variable "maximum_activation_duration" {
  description = <<-EOT
    Maximum time a member may stay active after activation (ISO 8601 duration).
    Examples: "PT1H" (1 h), "PT8H" (8 h), "P1D" (1 day).
    Entra PIM supports up to PT24H for most roles.
  EOT
  type        = string
  default     = "PT8H"

  validation {
    condition     = can(regex("^P(T?)([0-9]+[HMD])+$|^PT[0-9]+[HMS]$", var.maximum_activation_duration))
    error_message = "maximum_activation_duration must be an ISO 8601 duration, e.g. \"PT1H\", \"PT8H\", or \"P1D\"."
  }
}

variable "eligibility_years" {
  description = <<-EOT
    How many years the eligibility schedule remains valid.
    A time_rotating resource triggers re-application after this period so
    schedules are automatically renewed without manual intervention.
  EOT
  type        = number
  default     = 1

  validation {
    condition     = var.eligibility_years >= 1
    error_message = "eligibility_years must be at least 1."
  }
}

variable "role_assignments" {
  description = <<-EOT
    Azure RBAC role assignments to create for the Privileged group.
    Each entry:
      scope                = "<azure-resource-id>"   # required
      role_definition_name = "<built-in-role>"       # required
      name                 = "<human-friendly-key>"  # optional – used as the Terraform state key
    Leave empty ([]) when the assignment must be managed outside the module
    to avoid circular dependencies.
  EOT
  type = list(object({
    scope                = string
    role_definition_name = string
    name                 = optional(string, "")
  }))
  default = []
}
