# Repository Structure

## Top-level layout

```text
.
|-- .github/
|-- apps/
|-- packages/
|-- config/
|-- deploy/
|-- docs/
|-- scripts/
|-- CHANGELOG.md
|-- ROADMAP.md
|-- SECURITY.md
|-- README.md
```

## Apps

- `apps/control-plane-api`
- `apps/workflow-worker`
- `apps/tenant-bridge`
- `apps/console-web`

## Packages

- `packages/contracts`
- `packages/sdk`
- `packages/policies`

## Config

- export allowlist
- sanitization rules
- shared defaults

## Deploy

- Helm charts
- GitOps overlays
- environment examples

## Docs

- architecture
- product boundary
- sync strategy
- Kubernetes strategy
- ADRs as the repo evolves
