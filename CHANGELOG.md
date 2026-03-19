# Changelog

All notable changes to this product repository should be documented in this file.

The format is based on Keep a Changelog and semantic versioning.

## [0.2.0] - 2026-03-18

### Added

- **packages/contracts** — Go module with versioned API models (tenant, automation, workflow), connector interface, policy evaluator interface, and event bus contracts
- **packages/sdk** — Go SDK with base connector helper, connector registry, and HTTP API client
- **apps/control-plane-api** — Go HTTP server with tenant, automation, and workflow run endpoints; request ID, structured logger, and panic recovery middleware; in-memory store (PostgreSQL in Phase 1.1)
- **deploy/docker-compose.yml** — local development stack with PostgreSQL and control-plane-api

## [0.1.0] - 2026-03-18

### Added

- initial product architecture template
- security policy skeleton
- repository structure guidance
- local-to-product export rules
- PowerShell scripts for export, watch, and validation
- baseline CI workflow for validation and secret scanning
