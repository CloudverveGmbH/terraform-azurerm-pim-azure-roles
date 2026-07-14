output "eligible_group_id" {
  description = "Object ID of the Eligible group. Add users here to grant them PIM access."
  value       = azuread_group.eligible.object_id
}

output "eligible_group_name" {
  description = "Display name of the Eligible group (pim-<slug>-eligible)."
  value       = azuread_group.eligible.display_name
}

output "privileged_group_id" {
  description = "Object ID of the Privileged group. Use for role assignments and admin_group_object_ids."
  value       = azuread_group.privileged.object_id
}

output "privileged_group_name" {
  description = "Display name of the Privileged group (pim-<slug>)."
  value       = azuread_group.privileged.display_name
}

output "group_id" {
  description = "Alias for privileged_group_id (backward-compatible)."
  value       = azuread_group.privileged.object_id
}

output "principal_id" {
  description = "Alias for privileged_group_id. Use as principal_id in azurerm_role_assignment."
  value       = azuread_group.privileged.object_id
}

output "role_assignment_ids" {
  description = "Map of Azure RBAC role assignment IDs created by this module, keyed by assignment name."
  value       = { for k, ra in azurerm_role_assignment.this : k => ra.id }
}

output "resolved_approvers" {
  description = "Approvers with their resolved PIM type (singleUser/groupMembers) after auto-inference."
  value       = local.resolved_approvers
}
