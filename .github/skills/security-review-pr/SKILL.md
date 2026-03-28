---
name: security-review-pr
description: Review a pull request for security issues — secret exposure, excessive permissions, corporate data leakage, and workspace isolation violations.
---

# Security Review PR Skill

## When to use
- Any PR that touches `.github/workflows/`, `patches/`, `contracts/`, `schemas/`
- Any PR from an external contributor
- When a compliance scanner reports a violation
- Before merging any PR that involves token usage or workspace operations

## Review Checklist

### 1. Secret Exposure
- [ ] No tokens, API keys, passwords in committed files
- [ ] No secrets in commit messages or PR descriptions
- [ ] Workflow steps do not `echo` secret values
- [ ] `${{ secrets.NAME }}` pattern used — no hardcoded values

### 2. Corporate Data
- [ ] No `.intranet.` URLs in any tracked file
- [ ] No internal hostnames, IPs, or network topology
- [ ] `patches/` files are templates only — no real corporate data
- [ ] Compliance: `compliance/personal-product/product-compliance.policy.json` scan passed

### 3. Workspace Isolation
- [ ] No hardcoded `ws-socnew` or `ws-corp-1` in workflows, triggers, or scripts
- [ ] Each workspace uses its own token — no cross-contamination
- [ ] `workspace_id` read from inputs, never hardcoded
- [ ] Third-party workspace state not exposed in logs or outputs

### 4. Workflow Permissions
- [ ] No `permissions: write-all` without justification comment
- [ ] `GITHUB_TOKEN` permissions scoped to minimum needed
- [ ] `contents: write` only when files are committed

### 5. Code Security Patterns
- [ ] `parseSafeIdentifier()` on all inputs — NOT inside `fetch`/`postJson`
- [ ] `sanitizeForOutput()` on error messages
- [ ] `payload.scope` (singular) — never `payload.scopes`
- [ ] No `|| true` silencing auth errors
- [ ] No nested ternaries (ESLint `no-nested-ternary`)

### 6. Error Handling
- [ ] `set -euo pipefail` in all bash steps
- [ ] `echo "::error::"` before any exit
- [ ] No `|| true` without prior logging

## How to Review

### Step 1: Get PR files
```
get_pull_request_files(pr_number: N)
→ Look for changes to: .github/workflows/, patches/, contracts/, schemas/, trigger/
```

### Step 2: Search for anti-patterns
```
search_code("intranet", repo: "lucassfreiree/autopilot", branch: <pr-branch>)
search_code("ws-socnew", repo: "lucassfreiree/autopilot", branch: <pr-branch>)
search_code("ws-corp-1", repo: "lucassfreiree/autopilot", branch: <pr-branch>)
search_code("permissions: write-all", repo: "lucassfreiree/autopilot", branch: <pr-branch>)
```

### Step 3: Report findings

Format findings as:
```
## Security Review: PR #<N>

### ✅ Passed
- No secrets detected
- Workspace isolation respected

### ⚠️ Warnings
- Line 42 in workflow.yml: `|| true` without logging

### 🛑 Blockers
- <specific issue with file and line>
```

## CRITICAL: Third-Party Workspace Rule
If the PR adds operations on `ws-socnew` or `ws-corp-1` without documented authorization from `lucassfreiree`, it is an automatic **BLOCKER**.
