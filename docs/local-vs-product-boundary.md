# Local Runtime vs Product Boundary

## Principle

The local Autopilot is an operational workspace.

The product repository is a sanitized, generic, reusable software asset.

These two concerns must never collapse into one repository.

## What stays local

- customer names
- internal URLs
- internal registry addresses
- raw release state
- cached repositories
- private reports
- local secrets
- tokens and encrypted files
- customer-specific patches

## What can become product assets

- generic workflow patterns
- reusable wrappers and adapters
- generic docs and runbooks
- sanitizable scripts
- product contracts
- packaging and deployment manifests
- generic observability conventions
- generic CI/CD templates

## Promotion rule

A local artifact can move into the product repo only if it passes all checks:

1. reusable across customers
2. no private data
3. no private naming
4. no direct dependency on local corporate layout
5. has product-level docs
6. has test or validation strategy

## Best operating model

- local runtime repo or directory
- product repo on GitHub
- export allowlist between them
- sanitization before commit
- PR-based promotion into product repo
