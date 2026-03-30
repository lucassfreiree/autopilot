---
applyTo: "**"
---

# Security Instructions

Security rules that apply to ALL files and operations in this repository.

## Secrets and Credentials — NEVER

- NEVER commit tokens, API keys, passwords, certificates, or private keys
- NEVER include secrets in: commit messages, PR descriptions, issue bodies, workflow logs, CLAUDE.md, AGENTS.md, HANDOFF.md, or any tracked document
- NEVER hardcode secrets in workflow files — always use `${{ secrets.SECRET_NAME }}`
- NEVER log secret values even with `echo` or `::debug::` — GitHub masks known secrets but new ones may not be masked

## Corporate Data — NEVER in This Repo

- NEVER store corporate source code in `lucassfreiree/autopilot`
- NEVER store `.intranet.` URLs in tracked files (enforced by `compliance/personal-product/product-compliance.policy.json`)
- NEVER store internal IP addresses, hostnames, or network topology
- Patches in `patches/` are templates only — they must not contain real corporate data

## Token Isolation

Each workspace has exactly one authorized token:
| Workspace | Token Secret | Third Party? |
|---|---|---|
| `ws-default` | `BBVINET_TOKEN` | No |
| `ws-cit` | `CIT_TOKEN` | No |
| `ws-socnew` | — | **YES — LOCKED** |
| `ws-corp-1` | — | **YES — LOCKED** |

- NEVER use `BBVINET_TOKEN` for CIT operations
- NEVER use `CIT_TOKEN` for Getronics operations
- NEVER create tokens or credentials for `ws-socnew` or `ws-corp-1`

## Code Security Patterns

| Pattern | Rule |
|---|---|
| Input validation | Use `parseSafeIdentifier()` on all inputs — NEVER inside `fetch`/`postJson` |
| Error output | Use `sanitizeForOutput()` on error messages to prevent XSS |
| Response output | Use `sanitizeForOutput()` on ANY user-controlled value reflected in response JSON (e.g. image names, identifiers) |
| JWT claims | Read `payload.scope` (singular) — NEVER `payload.scopes` (plural) |
| URL validation | `validateTrustedUrl()` MUST be called right before EVERY `fetch()` call — defense-in-depth, even if already validated at input layer |
| Loop bounding | EVERY loop/filter over entries MUST be bounded by `MAX_ENTRIES_PER_EXEC` or `MAX_RESULTS` — NEVER iterate unbounded arrays from user input or external sources |
| Response entries | ALWAYS `.slice(0, MAX)` on entry arrays before including in response JSON — prevents DoS via large payloads |
| Swagger content | ASCII only — accented characters cause encoding issues and data exposure risk |
| Auth errors | NEVER silence with `|| true` — log first, then decide |

## Checkmarx Vulnerability Prevention (Mapped Patterns)

| Vulnerability | CWE | Files Affected | Fix Pattern | Date Mapped |
|---|---|---|---|---|
| Reflected XSS | CWE-79 | `oas-sre-controller.controller.ts` | `sanitizeForOutput()` on `image` field before response; bound `entries` with `MAX_SYNC_ENTRIES` | 2026-03-30 |
| SSRF | CWE-918 | `execute.controller.ts`, `oas-execute.controller.ts`, `oas-sre-controller.controller.ts` | `validateTrustedUrl()` inside `postJson`/`callAgent` AND right before every `fetch()` call | 2026-03-30 |
| DoS by Loop | CWE-834 | `agents-execute-logs.controller.ts`, `cronjob-result.controller.ts` | Bound incoming entries with `.slice(0, MAX_ENTRIES_PER_EXEC)`, bound snapshot entries, bound filter input with `MAX_RESULTS` | 2026-03-30 |

## Compliance Scanner

`compliance/personal-product/product-compliance.policy.json` scans for:
- `.intranet.` domain patterns
- Corporate identifier leakage

Run it before committing any documentation changes.

## Minimum Permissions Principle

- Workflow `permissions:` must specify only what is needed
- `permissions: write-all` requires a justification comment
- `GITHUB_TOKEN` permissions should be scoped: `contents: read`, `pull-requests: write`, etc.

## Reporting Security Issues

Use the `.github/ISSUE_TEMPLATE/workspace-isolation-violation.md` template for isolation violations.
