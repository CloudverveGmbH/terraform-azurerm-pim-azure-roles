# ---------------------------------------------------------------------------
# Module: pim-azure-role
# ---------------------------------------------------------------------------

data "azuread_client_config" "current" {}

# Look up directory object type for approvers that have no explicit type set.
# Allows passing a user or group object_id without specifying type manually.
data "azuread_directory_object" "approvers" {
  for_each  = { for a in var.approvers : a.object_id => a if a.type == null }
  object_id = each.key
}

locals {
  # The Terraform SPN is always an owner so both groups remain manageable
  # via automation. Callers may add further owners via var.group_owners.
  owners = distinct(concat(
    [data.azuread_client_config.current.object_id],
    var.group_owners,
  ))

  # Slug derived from group_display_name using the same pattern as the RENK pim-management module:
  # spaces and special chars are stripped, lowercased, hyphen-joined.
  # Example: "AKS Cluster Admin" → "aks-cluster-admin"
  # Resulting groups: "pim-aks-cluster-admin" (privileged) + "pim-aks-cluster-admin-eligible"
  group_slug = join("-", regexall("[a-z0-9]+", lower(var.group_display_name)))

  # Approval is derived from whether any approvers are configured.
  # Justification is an independent toggle; approval does not force it.
  require_approval      = length(var.approvers) > 0
  require_justification = var.require_justification

  # Resolve approver type: explicit value wins; when null, infer from the Entra
  # directory object type returned by data.azuread_directory_object.approvers.
  # "Group" (any casing / OData prefix) → "groupMembers"; everything else → "singleUser".
  resolved_approvers = [
    for a in var.approvers : {
      object_id = a.object_id
      type = a.type != null ? a.type : (
        endswith(lower(try(data.azuread_directory_object.approvers[a.object_id].type, "")), "group")
        ? "groupMembers"
        : "singleUser"
      )
    }
  ]
}

resource "time_rotating" "this" {
  rotation_years = var.eligibility_years
}

# ---------------------------------------------------------------------------
# Eligible group
# Members of this group can activate (PIM) into the privileged group.
# Add users here via normal Entra group membership – no terraform apply needed
# when team composition changes.
# ---------------------------------------------------------------------------
resource "azuread_group" "eligible" {
  display_name            = "pim-${local.group_slug}-eligible"
  description             = "Members eligible to activate 'pim-${local.group_slug}' via PIM."
  owners                  = local.owners
  security_enabled        = true
  prevent_duplicate_names = true
}

# Optional: seed initial members via Terraform.
# Leave var.members = [] to manage group membership outside Terraform.
resource "azuread_group_member" "eligible" {
  for_each = {
    for m in var.members :
    # display_name gives readable state keys (e.g. "Joscha Auwaerter");
    # falls back to object_id when display_name is not provided.
    (m.display_name != "" ? m.display_name : m.object_id) => m
  }

  group_object_id  = azuread_group.eligible.object_id
  member_object_id = each.value.object_id
}

# ---------------------------------------------------------------------------
# Privileged group
# Holds the Azure RBAC role assignments. Membership is granted only through
# PIM activation – never assigned permanently (except the Terraform SPN as owner).
# ---------------------------------------------------------------------------
resource "azuread_group" "privileged" {
  display_name            = "pim-${local.group_slug}"
  description             = "Active role holders for 'pim-${local.group_slug}'. Membership via PIM activation only."
  owners                  = local.owners
  security_enabled        = true
  prevent_duplicate_names = true
}

# PIM activation policy on the privileged group.
resource "azuread_group_role_management_policy" "this" {
  group_id = azuread_group.privileged.object_id
  role_id  = "member"

  activation_rules {
    maximum_duration      = var.maximum_activation_duration
    require_justification = local.require_justification
    require_approval      = local.require_approval

    dynamic "approval_stage" {
      for_each = local.require_approval ? [local.resolved_approvers] : []
      content {
        dynamic "primary_approver" {
          for_each = approval_stage.value
          content {
            type      = primary_approver.value.type
            object_id = primary_approver.value.object_id
          }
        }
      }
    }
  }

  eligible_assignment_rules {
    # Expiration is controlled by time_rotating below – no policy-level enforcement needed.
    expiration_required = false
  }
}

# Single schedule: the entire eligible group is the PIM principal.
# Every member of that group can activate into the privileged group.
resource "azuread_privileged_access_group_eligibility_schedule" "this" {
  group_id        = azuread_group_role_management_policy.this.group_id
  principal_id    = azuread_group.eligible.object_id
  assignment_type = "member"
  start_date      = time_rotating.this.id
  expiration_date = timeadd(time_rotating.this.id, "${var.eligibility_years * 365 * 24}h")
}

# Optional Azure RBAC role assignments scoped to the privileged group.
# Leave var.role_assignments = [] for circular-dependency cases (e.g. AKS).
resource "azurerm_role_assignment" "this" {
  for_each = {
    for ra in var.role_assignments :
    # Use explicit name when provided; fall back to "role::scope" for uniqueness.
    (ra.name != "" ? ra.name : "${ra.role_definition_name}::${ra.scope}") => ra
  }

  scope                = each.value.scope
  role_definition_name = each.value.role_definition_name
  principal_id         = azuread_group.privileged.object_id
}

# Entra group display names are limited to 256 characters. The eligible group
# carries the longest name ("pim-<slug>-eligible"); guard against overly long slugs.
check "group_name_length" {
  assert {
    condition     = length("pim-${local.group_slug}-eligible") <= 256
    error_message = "Derived group name 'pim-${local.group_slug}-eligible' exceeds the 256-character Entra limit. Shorten group_display_name."
  }
}
