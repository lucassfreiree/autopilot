# Security Policy

## Supported deployment model

This product is designed to support:

- single-tenant dedicated deployment
- multi-tenant shared control plane with isolated tenant execution
- hybrid model with customer-side tenant bridge

## Security baseline

- no secrets in git
- least privilege everywhere
- short-lived credentials
- outbound-only bridge from customer environment when possible
- mTLS between bridge and control plane
- OIDC for human access
- tenant-scoped authorization
- immutable audit trail for workflow actions

## Secret handling rules

- local developer auth: GitHub CLI or Git Credential Manager
- automation auth: GitHub App preferred
- fallback auth: fine-grained PAT with minimal scope and expiration
- runtime secrets: Vault, cloud secret manager, or External Secrets Operator backed store
- customer credentials must never be copied into product docs, templates, or tests

## Mandatory repository controls

- secret scan on every push and pull request
- dependency and filesystem scan in CI
- code review for export-rule changes
- signed release artifacts when packaging is added

## Incident rule

If a token, password, key, or private endpoint appears in chat, commit history, logs, screenshots, or exported docs, treat it as compromised:

1. revoke or rotate it
2. remove it from local files
3. verify it was not propagated to the product repository
4. record the incident and corrective action
