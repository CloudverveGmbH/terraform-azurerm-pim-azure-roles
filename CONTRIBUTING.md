# Contributing

## Sibling module parity

This module is one half of a pair:

- **`pim-azure-role`** — PIM for Azure RBAC roles (this repo).
- **`pim-entra-role`** — PIM for Entra directory roles.

The two modules deliberately share the same design (two-group Eligible/Privileged
pattern, slug-based naming, approver type inference, `time_rotating` eligibility,
identical activation-policy shape). **When you change shared logic here, apply the
equivalent change to `pim-entra-role`** so the two stay aligned. The PR template has
a checkbox for this.

> Readability beats cleverness. Prefer a few plain, obvious resources and locals
> over compact expressions that are hard to follow. Both modules are meant to be
> read and understood quickly.

---

## Making a change

### 1. Open a Pull Request targeting `main`

Use the PR template. Fill in the `<!-- KEEPACHANGELOG -->` block with
Keep-a-Changelog–style entries describing what changed from a user's perspective:

```markdown
<!-- KEEPACHANGELOG -->
### Added
- `require_justification` variable to make activation justification configurable.

### Fixed
- Group name length check no longer trips on long display names.
<!-- /KEEPACHANGELOG -->
```

Empty sub-sections are removed automatically.

### 2. Automation (`pr-changelog.yml`)

On every push to the PR branch the `PR Changelog` workflow:

1. Extracts the content between the `<!-- KEEPACHANGELOG -->` markers.
2. Drops empty sub-sections.
3. Appends a `([#N](…/pull/N))` link to every top-level bullet.
4. Replaces the `## [Unreleased]` block in `CHANGELOG.md`.
5. Commits `CHANGELOG.md` back to the PR branch.

If the markers are missing the workflow warns but does not fail.

### 3. CI (`ci.yml`)

Runs on the same trigger and validates:

- `terraform fmt -check -recursive`
- `terraform validate` (via the `examples/ci-validate` wrapper)
- `terraform test` (the mocked native test suite)

All checks must pass before merge.

---

## Merging and releasing

### Version stamping — before you open (or before you merge) the PR

`release.yml` only reads `CHANGELOG.md` on `main` and creates the tag + GitHub
Release. The version heading must therefore already be correct on `main` at merge time.

**Apply a bump label to the PR:**

| Label | Effect |
|---|---|
| `bump:patch` | `v0.1.0 → v0.1.1` |
| `bump:minor` | `v0.1.0 → v0.2.0` |
| `bump:major` | `v0.1.0 → v1.0.0` |

`pr-changelog.yml` detects the label, computes the next version from the latest
tag, and stamps the `CHANGELOG.md` heading (e.g. `## [0.2.0] - 2026-07-16`).
Without a bump label the heading stays `## [Unreleased]` and **no release is created**.

If two PRs are open at once they may compute the same next version. After the first
merges and tags, re-apply the label on the second PR to recompute.

### On merge to `main` → `release.yml`

1. Reads the top version heading from `CHANGELOG.md`. Aborts if `[Unreleased]`,
   already tagged, or a semver regression.
2. Runs the full test suite as a release gate.
3. Creates and pushes the `v<version>` tag.
4. Creates a GitHub Release from the matching `CHANGELOG.md` block.

The public Terraform Registry pulls new tags automatically (webhook set up once).

---

## Publishing to the Terraform Registry (one-time)

1. Create the GitHub repo named `terraform-azurerm-pim-azure-role` under `CloudverveGmbH`.
2. Go to <https://registry.terraform.io> → **Sign in with GitHub** → **Publish → Module**.
3. Select the repo. The Registry configures the webhook and ingests tagged releases.

The Registry reference becomes `CloudverveGmbH/pim-azure-role/azurerm`.
