# ---------------------------------------------------------------------------
# Module: pim-azure-role
# Purpose: Creates a PIM-enabled Entra ID security group with eligible
#          Azure RBAC assignments on arbitrary Azure resource scopes
#          (resource, resource group, subscription, management group).
#
# Usage pattern:
#   module "my_role_pim" {
#     source             = "./modules/pim-azure-role"
#     group_display_name = "My Role PIM"
#     members            = [{ object_id = data.azuread_user.alice.object_id }]
#     role_assignments   = [{ scope = azurerm_resource_group.app.id, role_definition_name = "Contributor" }]
#   }
#
# Circular-dependency note:
#   When the role assignment scope depends on a resource that in turn depends on
#   the group (e.g. AKS cluster referencing admin_group_object_ids), set
#   role_assignments = [] and create the azurerm_role_assignment externally.
# ---------------------------------------------------------------------------

variable "group_display_name" {
  description = "Display name for the Entra ID security group."
  type        = string
}

variable "group_description" {
  description = "Optional description for the security group."
  type        = string
  default     = ""
}

variable "group_owners" {
  description = <<-EOT
    Additional owner object IDs for the group (users or SPNs).
    The Terraform principal (data.azuread_client_config.current) is always
    added as an owner automatically so the group remains manageable.
  EOT
  type        = list(string)
  default     = []
}

variable "members" {
  description = "Entra ID objects that become PIM-eligible members of the group."
  type = list(object({
    object_id    = string
    display_name = optional(string, "")
  }))
}

variable "require_approval" {
  description = "Whether activating the role requires explicit approval from an approver."
  type        = bool
  default     = false
}

variable "maximum_activation_duration" {
  description = <<-EOT
    Maximum time a member may stay active after activation (ISO 8601 duration).
    Examples: "PT1H" (1 h), "PT8H" (8 h), "P1D" (1 day).
    Entra PIM supports up to PT24H for most roles.
  EOT
  type        = string
  default     = "PT8H"
}

variable "approvers" {
  description = <<-EOT
    PIM approvers, required when require_approval = true.
    Each entry: { object_id = "<uuid>", type = "singleUser" | "groupMembers" }
    type defaults to "singleUser".
  EOT
  type = list(object({
    object_id = string
    type      = optional(string, "singleUser")
  }))
  default = []
}

variable "eligibility_years" {
  description = <<-EOT
    How many years each eligibility schedule remains valid.
    A time_rotating resource triggers re-application after this period so
    schedules are automatically renewed without manual intervention.
  EOT
  type    = number
  default = 1
}

variable "role_assignments" {
  description = <<-EOT
    Azure RBAC role assignments to create for the group.
    Each entry: { scope = "<azure-resource-id>", role_definition_name = "<built-in-role>" }
    Leave empty ([]) when the assignment must be managed outside the module
    to avoid circular dependencies.
  EOT
  type = list(object({
    scope                = string
    role_definition_name = string
  }))
  default = []
}

variable "tags" {
  description = "Tags applied to Azure resources created by this module."
  type        = map(string)
  default     = {}
}
