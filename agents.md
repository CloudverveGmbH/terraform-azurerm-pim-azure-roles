# AI Agent Context — PIM Terraform modules (`pim-azure-role` + `pim-entra-role`)

This file is **identical in both repositories** (`pim-azure-role` and
`pim-entra-role`) and describes how an AI agent should work in either one.

---

## The two modules are a mirrored pair

| Module | Purpose | Registry ref |
|---|---|---|
| `pim-azure-role` | Just-in-time PIM access to **Azure RBAC roles** (resource / RG / subscription / MG scope) | `CloudverveGmbH/pim-azure-role/azurerm` |
| `pim-entra-role` | Just-in-time PIM access to **Entra directory roles** (tenant-wide) | `CloudverveGmbH/pim-entra-role/azuread` |

**They must stay behaviourally aligned.** The following is shared and should look
and behave the same in both modules:

- Two-group pattern: `pim-<slug>-eligible` (members) → PIM eligibility → `pim-<slug>` (holds the role).
- Slug derivation: `join("-", regexall("[a-z0-9]+", lower(<name>)))`.
- Owners: the Terraform SPN (`data.azuread_client_config.current`) is always an owner.
- Approver type auto-inference via `data.azuread_directory_object` → `singleUser` / `groupMembers`.
- `time_rotating` driving the eligibility schedule.
- `azuread_group_role_management_policy` activation rules, including the dynamic `approval_stage`.
- Variable validations (duration, eligibility years, approver types, group name).
- `check "group_name_length"` guard.
- Output set: `eligible_group_id/name`, `privileged_group_id/name`, `group_id`, `principal_id`, `resolved_approvers`.

**Intentional differences** (do not "fix" these):

| Aspect | `pim-azure-role` | `pim-entra-role` |
|---|---|---|
| Role assignment | `azurerm_role_assignment` (0..n via `role_assignments`) | `azuread_directory_role_assignment` (single) |
| Privileged group | plain security group | `assignable_to_role = true` |
| Primary role input | `role_assignments[]` | `entra_role_display_name` |
| `group_display_name` | **required** (no role name to derive from) | — |
| `override_group_display_name` | — | **optional** override; when omitted slug is derived from `entra_role_display_name` |
| `maximum_activation_duration` default | `PT8H` | `PT4H` |
| Extra output | `role_assignment_ids` | `directory_role_assignment_id` |

---

## Rule: when working locally, check for the sibling module

Before making a change that touches **shared logic**, check whether the sibling
module is also checked out locally (typical layout: both live side by side, e.g.
`d:\cloudverve\pim-azure-role` and `d:\cloudverve\pim-entra-role`).

- **Sibling is present locally** → apply the equivalent change to it in the same
  session so the pair does not drift. Run its test suite too.
- **Sibling is not present locally** → note in your summary that the sibling needs
  the same change in its own repo/PR, so a human can follow up.

---

## Guiding principle: readability over cleverness

Prefer plain, obvious resources and locals over compact one-liners. These modules
are meant to be read and understood in a single pass. Do not introduce clever
expressions, indirection, or abstractions to save a few lines.

Also follow the surrounding conventions:

- Do not add `private_dns_zone_group`-style external ownership conflicts — the
  module owns its groups/policies; callers own only what the README documents.
- Keep comments purposeful (explain *why*, not *what*).

---

## After every change

Always run, from the module directory:

```bash
terraform fmt -recursive
terraform init -backend=false
terraform test
```

A task is not complete until `terraform test` passes. If a test needs new coverage
for your change, add a `run` block to `tests.tftest.hcl`. Tests use `mock_provider`
so they run without Azure credentials; assert on input-derived outputs (group
names, `resolved_approvers`, assignment keys) which are deterministic at plan time.

---

## Release train (see CONTRIBUTING.md)

- Changelog is human-authored in the PR body between `<!-- KEEPACHANGELOG -->` markers.
- `pr-changelog.yml` stamps `CHANGELOG.md`; a `bump:patch|minor|major` label sets the version.
- `release.yml` tags `vX.Y.Z` and creates the GitHub Release on merge to `main`.
- The Terraform Registry ingests tags automatically (pull model, no token).
- Do **not** hand-edit tags or push directly to `main`.

---

## File map (both modules)

| File | Purpose |
|---|---|
| `main.tf` | Groups, PIM policy, eligibility schedule, role assignment, `check` block |
| `variables.tf` | Inputs + validations |
| `outputs.tf` | Group IDs/names, principal_id, resolved_approvers, assignment output |
| `versions.tf` | `required_version` + `required_providers` |
| `tests.tftest.hcl` | Mocked native test suite |
| `examples/ci-validate/main.tf` | Wrapper used by CI for `terraform validate` |
| `.github/workflows/` | `ci.yml`, `pr-changelog.yml`, `release.yml` |
| `README.md` | Usage (English + German) |
| `CHANGELOG.md` | Keep a Changelog, versions without leading `v` |
