# Local to GitHub Sync Strategy

## Goal

Detect relevant changes in the local Autopilot runtime and promote only generic, sanitized, product-worthy changes into the GitHub product repository.

## Recommended mechanism

Use a local watcher plus exporter instead of pushing directly from the operational runtime.

Flow:

1. local watcher detects changes in the local Autopilot root
2. exporter reads `config/product-export.map.json`
3. only allowlisted files are copied
4. content redactions are applied
5. forbidden patterns are blocked
6. `scripts/validate-product-export.ps1` validates the product repo tree
7. `scripts/sync-product-pr.ps1` creates or refreshes `sync/autopilot`
8. the branch is pushed to GitHub
9. a pull request into `main` is created or updated automatically

## Why this model

- local environment remains free to carry customer specifics
- GitHub repository stays reusable and clean
- propagation is auditable
- security gates run before publication

## GitHub authentication recommendation

Preferred:

- GitHub App with repository-scoped permissions

Fallback:

- fine-grained PAT with minimal scope and expiration

Avoid:

- classic PATs
- long-lived shared tokens
- embedding tokens in scripts or config files

## Promotion policy

Recommended defaults:

- docs and templates: auto-export and auto-PR
- scripts and code: auto-export into `sync/autopilot` plus mandatory review before merge
- config rules: mandatory review
- any security-sensitive change: manual approval only

## Validation gates before commit or PR

- secret scan
- forbidden corporate markers scan
- JSON and YAML parse validation
- required file presence
- changelog or docs update when architecture changes

## Recommended operating mode

- default branch: `main`
- automation branch: `sync/autopilot`
- watcher mode: `sync-pr`
- merge policy: review and merge PR, never direct write to `main` from the local watcher
