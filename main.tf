# ---------------------------------------------------------------------------
# Module: pim-azure-role
# ---------------------------------------------------------------------------

data "azuread_client_config" "current" {}

locals {
  # The Terraform SPN is always an owner so the group stays manageable via
  # automation. Callers may add further owners via var.group_owners.
  owners = distinct(concat(
    [data.azuread_client_config.current.object_id],
    var.group_owners,
  ))

  # Justification is automatically required whenever an approval workflow is
  # configured – if you have to wait for a human to approve, a reason is a
  # minimum expectation.
  require_justification = length(var.approvers) > 0
}

# Rotating time anchor: drives both start_date and expiration_date of every
# eligibility schedule. When the rotation fires, Terraform updates all
# schedules automatically on the next apply — no manual renewal needed.
resource "time_rotating" "this" {
  rotation_years = var.eligibility_years
}

resource "azuread_group" "this" {
  display_name     = var.group_display_name
  description      = var.group_description
  owners           = local.owners
  security_enabled = true
}

resource "azuread_group_role_management_policy" "this" {
  group_id = azuread_group.this.object_id
  role_id  = "member"

  activation_rules {
    maximum_duration      = var.maximum_activation_duration
    require_justification = local.require_justification
    require_approval      = var.require_approval

    dynamic "approval_stage" {
      # Block is only emitted when approval is required; approval_stage.value
      # is the list of approvers so the inner for_each can iterate over them.
      for_each = var.require_approval ? [var.approvers] : []
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

  lifecycle {
    precondition {
      condition     = !var.require_approval || length(var.approvers) > 0
      error_message = "At least one entry in var.approvers is required when require_approval = true."
    }
  }
}

# One eligibility schedule per member, keyed by object_id for stable for_each.
resource "azuread_privileged_access_group_eligibility_schedule" "members" {
  for_each = { for m in var.members : m.object_id => m }

  group_id        = azuread_group_role_management_policy.this.group_id
  principal_id    = each.value.object_id
  assignment_type = "member"
  start_date      = time_rotating.this.id
  expiration_date = timeadd(time_rotating.this.id, "${var.eligibility_years * 365 * 24}h")
}

# Optional Azure RBAC role assignments scoped to arbitrary Azure resources.
# Leave var.role_assignments = [] for circular-dependency cases (e.g. AKS).
resource "azurerm_role_assignment" "this" {
  for_each = {
    for ra in var.role_assignments :
    "${ra.scope}::${ra.role_definition_name}" => ra
  }

  scope                = each.value.scope
  role_definition_name = each.value.role_definition_name
  principal_id         = azuread_group.this.object_id
}
