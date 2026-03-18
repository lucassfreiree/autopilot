# Product Architecture

## Product shape

The commercial version of Autopilot should not be a bundle of customer-specific scripts.

It should be a platform with two clearly separated planes:

- control plane
- tenant execution plane

## Core components

### 1. Control Plane API

Responsibilities:

- tenant management
- automation catalog
- workflow dispatch
- policy checks
- audit metadata
- release and connector metadata

Recommended stack:

- Go
- PostgreSQL
- OpenAPI-first REST plus internal gRPC or ConnectRPC

### 2. Workflow Worker

Responsibilities:

- durable workflow execution
- retries and compensations
- CI polling
- approval checkpoints
- status transitions

Recommended stack:

- Go
- Temporal OSS

### 3. Tenant Bridge

Responsibilities:

- execute jobs inside customer network or customer cluster
- expose only outbound connectivity when possible
- run approved connector actions
- publish telemetry and results

Recommended stack:

- Go
- containerized runtime
- optional Windows service package when customer environments require it

### 4. Console Web

Responsibilities:

- tenant admin UI
- run history
- audit views
- policy and connector catalog
- support and diagnostics views

Recommended stack:

- Next.js
- TypeScript

### 5. Shared Contracts and SDK

Responsibilities:

- versioned API models
- connector interfaces
- policy input schemas
- test fixtures

## Multi-tenant model

Use a shared control plane with strict tenant isolation by default.

Recommended tenant isolation controls:

- `tenant_id` on every domain record
- tenant-scoped API tokens or service identities
- tenant-scoped encryption context
- tenant-scoped audit partitions
- tenant-aware workflow queues
- per-tenant quotas and rate limits

## Product boundaries

Do not turn the current local operational scripts directly into the final product API.

Instead:

1. abstract the core workflow model
2. turn scripts into adapters or connectors
3. keep customer-specific execution inside the tenant bridge
4. keep product logic in the control plane

## Product packaging model

- Community or base edition:
  - single-tenant
  - limited connectors
  - manual upgrades
- Enterprise edition:
  - multi-tenant
  - SSO
  - advanced policy and audit
  - GitOps packaging
  - support and upgrade tooling
