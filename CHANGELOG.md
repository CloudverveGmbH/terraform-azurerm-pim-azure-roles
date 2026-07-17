# Changelog

All notable changes to this module are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.2] - 2026-07-17
### Changed
- README und Agents.md adjusted ([#1](https://github.com/CloudverveGmbH/terraform-azurerm-pim-azure-roles/pull/1))
- Updated github pipelines ([#1](https://github.com/CloudverveGmbH/terraform-azurerm-pim-azure-roles/pull/1))


## [0.1.0] - 2026-07-16

### Added

- Two-group PIM pattern (Eligible + Privileged) for Azure RBAC roles.
- Automatic group naming from `group_display_name` (`pim-<slug>` / `pim-<slug>-eligible`).
- Approver type auto-inference (singleUser / groupMembers) from the Entra directory object.
- Auto-renewing eligibility schedule via `time_rotating`.
- Optional `role_assignments` for Azure RBAC, with a documented circular-dependency pattern (e.g. AKS).
- Explicit `require_justification` toggle (default `true`).
- Input validation for durations, eligibility years, approver types, and group names.
- `versions.tf` pinning Terraform `>= 1.9`, azuread `>= 3.0`, azurerm `>= 4.0`, time `>= 0.10`.
- Native `terraform test` suite with mocked providers.
- Outputs: `eligible_group_name`, `privileged_group_name`, `role_assignment_ids`, `resolved_approvers`.
