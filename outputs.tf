output "group_id" {
  description = "Object ID of the PIM-enabled security group."
  value       = azuread_group.this.object_id
}

output "principal_id" {
  description = "Alias for group_id. Use directly as principal_id in azurerm_role_assignment."
  value       = azuread_group.this.object_id
}
