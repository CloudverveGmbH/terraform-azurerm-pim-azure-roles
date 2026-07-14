# ---------------------------------------------------------------------------
# Native test suite for pim-azure-role.
# All providers are mocked so tests run with no Azure credentials.
# Assertions target input-derived outputs (group names, approver types,
# role-assignment keys) that are deterministic at plan time.
# ---------------------------------------------------------------------------

mock_provider "azuread" {
  # object_id feeds the group owners list, which the provider validates as a UUID.
  mock_data "azuread_client_config" {
    defaults = {
      object_id = "00000000-0000-0000-0000-000000000000"
    }
  }
}
mock_provider "azurerm" {}
mock_provider "time" {}

# The slug is lowercased and stripped to alphanumeric runs joined by hyphens.
run "group_names_derived_from_display_name" {
  command = plan

  variables {
    group_display_name = "AKS Cluster Admin"
  }

  assert {
    condition     = output.eligible_group_name == "pim-aks-cluster-admin-eligible"
    error_message = "Eligible group name not derived correctly from group_display_name."
  }

  assert {
    condition     = output.privileged_group_name == "pim-aks-cluster-admin"
    error_message = "Privileged group name not derived correctly from group_display_name."
  }
}

# Special characters and extra whitespace must collapse to a clean slug.
run "slug_strips_special_characters" {
  command = plan

  variables {
    group_display_name = "AKS  Cluster/Admin! (prod)"
  }

  assert {
    condition     = output.privileged_group_name == "pim-aks-cluster-admin-prod"
    error_message = "Slug did not normalise special characters and whitespace."
  }
}

# Explicit approver type must be preserved (no auto-inference).
run "explicit_approver_type_is_preserved" {
  command = plan

  variables {
    group_display_name = "Subscription Owner"
    approvers = [
      { object_id = "11111111-1111-1111-1111-111111111111", type = "groupMembers" },
    ]
  }

  assert {
    condition     = one(output.resolved_approvers).type == "groupMembers"
    error_message = "Explicit approver type should be kept unchanged."
  }
}

# Empty approvers → no approval stage, resolved_approvers is empty.
run "no_approvers_yields_empty_resolved_list" {
  command = plan

  variables {
    group_display_name = "Reader Role"
  }

  assert {
    condition     = length(output.resolved_approvers) == 0
    error_message = "Expected no resolved approvers when approvers is empty."
  }
}

# Role-assignment map is keyed by the explicit name when provided.
run "role_assignment_uses_explicit_name_key" {
  command = plan

  variables {
    group_display_name = "AKS Cluster Admin"
    role_assignments = [{
      scope                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
      role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
      name                 = "aks-cluster-admin"
    }]
  }

  assert {
    condition     = contains(keys(output.role_assignment_ids), "aks-cluster-admin")
    error_message = "Role assignment should be keyed by the explicit name."
  }
}

# Members are keyed by display_name for readable state addresses.
run "members_keyed_by_display_name" {
  command = plan

  variables {
    group_display_name = "AKS Cluster Admin"
    members = [
      { object_id = "22222222-2222-2222-2222-222222222222", display_name = "Alice" },
    ]
  }

  assert {
    condition     = contains(keys(azuread_group_member.eligible), "Alice")
    error_message = "Members should be keyed by display_name when provided."
  }
}
