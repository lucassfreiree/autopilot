# Kubernetes Strategy

## Deployment target

The product should be cloud-native from the start and deployable to Kubernetes with minimal environment-specific change.

## Baseline requirements

- container image per service
- externalized configuration
- health endpoints
- readiness and liveness probes
- horizontal scaling for stateless services
- separate secrets from config
- ingress or gateway management
- network policies
- observability endpoints

## Recommended runtime split

- `control-plane-api`
  - stateless deployment
  - HPA enabled
- `workflow-worker`
  - worker deployment with queue-based concurrency
- `console-web`
  - stateless deployment
- `tenant-bridge`
  - deploy in customer cluster or customer VM, not in shared SaaS cluster by default

## Recommended platform components

- Helm for packaging
- Argo CD for GitOps
- External Secrets Operator for runtime secret materialization
- Prometheus for metrics
- Loki for logs
- Tempo for traces

## Required probes

- startup probe for slow boot services
- readiness probe for dependency-safe traffic admission
- liveness probe only where restart is safe and meaningful

## Config model

- product defaults in chart values
- per-environment overlays
- per-tenant config outside chart defaults
- no secrets in Helm values committed to git
