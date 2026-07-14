## Summary

_Briefly describe what this PR does._

## Sibling module

This module is one of a pair (`pim-azure-role` + `pim-entra-role`) that must stay
behaviourally aligned. If your change touches shared logic (slug derivation, the
two-group pattern, approver inference, activation policy), apply the equivalent
change to the sibling module.

- [ ] Change is module-specific, sibling not affected
- [ ] Equivalent change applied to the sibling module
- [ ] N/A

## Changelog

Document the user-visible changes included in this PR in [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format.
The block between the markers below will be extracted automatically and replace the `[Unreleased]` section in `CHANGELOG.md`.

<!-- KEEPACHANGELOG -->
### Added
-

### Changed
-

### Fixed
-

### Removed
-
<!-- /KEEPACHANGELOG -->

_Empty sub-sections are removed automatically. A `([#N](…))` link is appended to each bullet by CI._

## Checklist

- [ ] `terraform fmt` applied
- [ ] `terraform test` passes locally
- [ ] Changelog block filled in above
- [ ] Bump label applied (`bump:patch` / `bump:minor` / `bump:major`) if this should release
