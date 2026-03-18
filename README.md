# Autopilot Product Template

This directory is a product-oriented template for evolving the current Autopilot into a reusable, secure, multi-tenant platform.

It is intentionally separated from the local corporate runtime.

## Product goal

Turn the current local automation flow into a commercial-grade platform with:

- multi-tenant control plane
- secure tenant bridge for customer environments
- reusable workflow engine
- policy and audit controls
- Kubernetes-ready deployment
- controlled local-to-product sync with sanitization

## Recommended product architecture

- `apps/control-plane-api`
  - multi-tenant API, authn/authz, automation catalog, execution control
- `apps/workflow-worker`
  - durable workflow execution, retries, polling, approvals, rollout orchestration
- `apps/tenant-bridge`
  - customer-side agent that executes automations against local systems
- `apps/console-web`
  - product UI for operators, auditors, and tenant admins
- `packages/contracts`
  - API contracts and shared schemas
- `packages/sdk`
  - SDK for connectors and automation plugins
- `packages/policies`
  - shared policy definitions, validation rules, and reusable controls
- `deploy`
  - Helm, GitOps, environment overlays, and runtime docs

## Recommended stack

- Backend services: Go
- Workflow orchestration: Temporal OSS
- Console: Next.js + TypeScript
- Primary database: PostgreSQL
- Identity: Keycloak
- Observability: OpenTelemetry + Prometheus + Loki + Tempo
- GitOps deploy: Argo CD
- Secrets in Kubernetes: External Secrets Operator
- CI/CD: GitHub Actions
- Security gates: Gitleaks, Trivy, Semgrep

## Why this stack

- Go keeps control-plane and bridge services small, fast, and operationally simple.
- Temporal is a strong fit for long-running release flows, retries, approvals, and durable state.
- PostgreSQL is the best default transactional core for a product at this stage.
- Keycloak avoids custom auth and supports OIDC, SSO, and tenant-aware RBAC.
- OpenTelemetry keeps the platform vendor-neutral from the start.
- Argo CD and Helm make Kubernetes delivery repeatable and auditable.

## Hard boundary: local runtime vs product repo

The local Autopilot remains an operational environment.

This product template is a separate sanitized repository model.

Never push the following from local runtime into the product repository:

- secrets
- tokens
- private URLs
- customer names
- internal branches
- customer-specific pipelines
- raw audit logs
- cached repositories
- state snapshots containing internal details

Use the export scripts in `scripts/` and the allowlist in `config/` to move only sanitized, reusable product assets into the product repository.

## Automatic local-to-product sync

Use:

- `scripts/export-product-snapshot.ps1`
- `scripts/sync-product-pr.ps1`
- `scripts/watch-product-sync.ps1`
- `scripts/validate-product-export.ps1`
- `scripts/install-product-sync-task.ps1`

The intended flow is:

1. watch the local Autopilot source root
2. export only allowlisted files
3. sanitize private content
4. block secrets and private markers
5. validate the product repo tree
6. commit into `sync/autopilot`
7. push the sync branch
8. create or update a pull request into `main`

## GitHub guidance

- Prefer a GitHub App for automation.
- If a PAT is temporarily required, use a fine-grained token with minimal scope and short expiration.
- Never store credentials in this repository.
- Treat any token exposed in chat, logs, shell history, or screenshots as compromised and rotate it.
- Use `GITHUB_PR_TOKEN` or `GITHUB_TOKEN` only as runtime environment variables when PR automation must call the GitHub API.

## First practical steps

1. Create a new public or private GitHub repository for the product.
2. Copy this template into that repository.
3. Configure the local source root and product repo root through environment variables.
4. Tune the allowlist and redaction rules in `config/`.
5. Start with docs, contracts, packaging, and the export pipeline before moving business logic.
6. Replace corporate-specific names, URLs, and workflows with generic product concepts.
7. Run `task sync-pr` for one-shot promotion or `task install-sync-task` to install the watcher-backed routine.
8. If Task Scheduler registration is blocked by local permissions, the installer falls back to the user's Startup folder automatically.
