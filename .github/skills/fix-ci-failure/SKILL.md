---
name: fix-ci-failure
description: Diagnose and auto-fix CI failures in corporate repos. Use when CI/esteira fails after deploy.
---

# CI Failure Auto-Fix Skill

## When to use
- Corporate CI (Esteira de Build NPM) failed after deploy
- apply-source-change CI Gate reported failure
- User mentions CI error, test failure, or lint error

## Diagnosis Flow

### Step 1: Get the corporate commit SHA
```
get_file_contents(
  path: "state/workspaces/ws-default/controller-release-state.json",
  branch: "autopilot-state"
)
→ Extract: lastReleasedSha, ciResult, status
```

### Step 2: Check CI logs
```
list_commits(sha: "autopilot-state", per_page: 10)
→ Look for: ci-logs-controller-*.txt files
→ Read the latest one for actual error
```

### Step 3: Identify error pattern

| Log Pattern | Error Type | Fix |
|---|---|---|
| `error TS2769` | TypeScript type mismatch | Check @types/, add proper casts |
| `error TS2304` | Missing import | Add import statement |
| `no-use-before-define` | Function order | Move function definition UP |
| `no-unused-vars` | Dead code | Remove unused function |
| `no-nested-ternary` | Nested ternary | Replace with if/else |
| `FAIL src/__tests__` | Test failure | Check if test expects old behavior |
| `duplicate tag` | Version exists | Bump version |
| `Insufficient scope` | JWT claim wrong | Use scope (singular) |
| `Reflected_XSS` | XSS in response | Use sanitizeForOutput() |

### Step 4: Auto-fix
1. Create corrected patch in `patches/`
2. Bump version (previous tag already in registry)
3. Increment run in `trigger/source-change.json`
4. `push_files` with all changes → PR → merge
5. Monitor new workflow run

### Step 5: Monitor until success
```
list_commits(sha: "autopilot-state", per_page: 5)
→ Look for: "state: controller source-change", "audit: source-change"
→ Verify: promoted=true in release state
```

## CRITICAL: NEVER ask the user. Diagnose + fix + deploy automatically.
