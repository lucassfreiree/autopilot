#!/bin/bash
# Pre-commit dual-side validation for Claude Code
# Runs BEFORE git commit — validates patches against both controller and agent contracts
# Exit: {"decision":"approve"} or {"decision":"block","reason":"..."}
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '/home/user/autopilot')"
TRIGGER="$REPO_ROOT/trigger/source-change.json"
CONTRACT="$REPO_ROOT/contracts/interface-contract.json"
CHECKMARX="$REPO_ROOT/schemas/checkmarx-patterns.json"
VIOLATIONS=()

# ── Helper ──
add_violation() { VIOLATIONS+=("$1"); }

# ── 0. Check if trigger exists ──
if [ ! -f "$TRIGGER" ]; then
  echo '{"decision":"approve"}'
  exit 0
fi

COMPONENT=$(jq -r '.component // "controller"' "$TRIGGER" 2>/dev/null || echo "controller")
VERSION=$(jq -r '.version // ""' "$TRIGGER" 2>/dev/null || echo "")
CHANGES=$(jq -c '.changes // []' "$TRIGGER" 2>/dev/null || echo "[]")

# Collect patch files referenced by trigger
PATCH_FILES=()
while IFS= read -r ref; do
  [ -z "$ref" ] || [ "$ref" = "null" ] && continue
  FULL="$REPO_ROOT/$ref"
  [ -f "$FULL" ] && PATCH_FILES+=("$FULL")
done < <(echo "$CHANGES" | jq -r '.[].content_ref // empty' 2>/dev/null)

# If no patches referenced, approve
if [ ${#PATCH_FILES[@]} -eq 0 ]; then
  echo '{"decision":"approve"}'
  exit 0
fi

# ── 1. Version Format (Rule 1) ──
if [ -n "$VERSION" ]; then
  PATCH_NUM=$(echo "$VERSION" | cut -d. -f3)
  if [ "$PATCH_NUM" -ge 10 ] 2>/dev/null; then
    add_violation "version-format: $VERSION has patch >= 10. After X.Y.9 -> X.(Y+1).0"
  fi
fi

# ── 2. JWT Scope Singular (Rule 4) ──
for f in "${PATCH_FILES[@]}"; do
  if grep -qE 'payload\.scopes|"scopes"|\.scopes\b|\bscopes\s*:' "$f" 2>/dev/null; then
    add_violation "jwt-scope-singular: $(basename "$f") uses 'scopes' (plural). MUST be 'scope' (singular)"
  fi
done

# ── 3. No validateTrustedUrl in fetch (Rule 5) ──
for f in "${PATCH_FILES[@]}"; do
  if grep -qE 'fetch\(.*validateTrustedUrl|postJson\(.*validateTrustedUrl' "$f" 2>/dev/null; then
    add_violation "no-validate-in-fetch: $(basename "$f") passes validateTrustedUrl inside fetch/postJson. Call it BEFORE, not as argument"
  fi
done

# ── 4. No nested ternary (Rule 6) ──
for f in "${PATCH_FILES[@]}"; do
  if grep -qE '\?.*\?.*:.*:' "$f" 2>/dev/null; then
    add_violation "no-nested-ternary: $(basename "$f") has nested ternary. ESLint will reject"
  fi
done

# ── 5. Security: XSS — sanitizeForOutput required (Rule 10) ──
for f in "${PATCH_FILES[@]}"; do
  HAS_REQ=0; grep -qE 'req\.(body|query|params)' "$f" 2>/dev/null && HAS_REQ=1
  HAS_RES=0; grep -qE 'res\.(json|send)\(' "$f" 2>/dev/null && HAS_RES=1
  HAS_SANITIZE=0; grep -qE 'sanitizeForOutput' "$f" 2>/dev/null && HAS_SANITIZE=1
  if [ "$HAS_REQ" -eq 1 ] && [ "$HAS_RES" -eq 1 ] && [ "$HAS_SANITIZE" -eq 0 ]; then
    add_violation "security-xss: $(basename "$f") reads req input AND writes response but missing sanitizeForOutput import"
  fi
done

# ── 6. Security: SSRF — validateTrustedUrl required (Rule 11) ──
for f in "${PATCH_FILES[@]}"; do
  HAS_FETCH=0; grep -qE 'fetch\(|postJson\(|callAgent\(' "$f" 2>/dev/null && HAS_FETCH=1
  HAS_VALIDATE=0; grep -qE 'validateTrustedUrl' "$f" 2>/dev/null && HAS_VALIDATE=1
  if [ "$HAS_FETCH" -eq 1 ] && [ "$HAS_VALIDATE" -eq 0 ]; then
    add_violation "security-ssrf: $(basename "$f") uses fetch/postJson/callAgent without validateTrustedUrl"
  fi
done

# ── 7. Security: DoS — loop bounds required (Rule 12) ──
for f in "${PATCH_FILES[@]}"; do
  HAS_LOOP=0; grep -qE 'for\s*\(.*\.length' "$f" 2>/dev/null && HAS_LOOP=1
  HAS_BOUND=0; grep -qE 'Math\.min' "$f" 2>/dev/null && HAS_BOUND=1
  if [ "$HAS_LOOP" -eq 1 ] && [ "$HAS_BOUND" -eq 0 ]; then
    add_violation "security-dos-loop: $(basename "$f") has for-loop with .length but no Math.min bound"
  fi
done

# ── 8. No hardcoded secrets (Rule 13) ──
for f in "${PATCH_FILES[@]}"; do
  if grep -qEi '(password|secret|api_key|token)\s*[:=]\s*["\x27][A-Za-z0-9+/]{8,}' "$f" 2>/dev/null; then
    add_violation "hardcoded-secret: $(basename "$f") may contain hardcoded secrets"
  fi
done

# ── 9. No for...of (ESLint blocks it) ──
for f in "${PATCH_FILES[@]}"; do
  if grep -qE 'for\s*\(\s*(const|let|var)\s+\w+\s+of\s' "$f" 2>/dev/null; then
    add_violation "no-for-of: $(basename "$f") uses for...of. Use .map/.filter/.reduce instead"
  fi
done

# ── 10. expiresIn must be numeric ──
for f in "${PATCH_FILES[@]}"; do
  if grep -qE "expiresIn:\s*['\"]" "$f" 2>/dev/null; then
    HAS_PARSE=0; grep -qE 'parseExpiresIn' "$f" 2>/dev/null && HAS_PARSE=1
    if [ "$HAS_PARSE" -eq 0 ]; then
      add_violation "interface-jwt-expiresIn: $(basename "$f") sets expiresIn as string without parseExpiresIn()"
    fi
  fi
done

# ── 11. Interface surface cross-check ──
if [ -f "$CONTRACT" ]; then
  CTRL_SURFACE=$(jq -r '.interfaceSurface.controller[]' "$CONTRACT" 2>/dev/null || true)
  AGENT_SURFACE=$(jq -r '.interfaceSurface.agent[]' "$CONTRACT" 2>/dev/null || true)

  TOUCHES_INTERFACE=false
  for change in $(echo "$CHANGES" | jq -r '.[].target_path // empty' 2>/dev/null); do
    for surf in $CTRL_SURFACE $AGENT_SURFACE; do
      if echo "$change" | grep -qF "$(basename "$surf")"; then
        TOUCHES_INTERFACE=true
        break 2
      fi
    done
  done

  if [ "$TOUCHES_INTERFACE" = "true" ]; then
    OTHER_SIDE="agent"
    [ "$COMPONENT" = "agent" ] && OTHER_SIDE="controller"
    add_violation "WARN:dual-side-required: Changes touch interface surface files. Validate $OTHER_SIDE side too before deploy"
  fi
fi

# ── 12. Run number check ──
RUN_NUM=$(jq -r '.run // 0' "$TRIGGER" 2>/dev/null || echo 0)
if [ "$RUN_NUM" -le 0 ]; then
  add_violation "run-not-set: trigger run number is 0 or missing. Workflow will NOT trigger"
fi

# ── Result ──
ERRORS=()
WARNINGS=()
for v in "${VIOLATIONS[@]}"; do
  if [[ "$v" == WARN:* ]]; then
    WARNINGS+=("${v#WARN:}")
  else
    ERRORS+=("$v")
  fi
done

if [ ${#WARNINGS[@]} -gt 0 ]; then
  for w in "${WARNINGS[@]}"; do
    echo "⚠️  $w" >&2
  done
fi

if [ ${#ERRORS[@]} -gt 0 ]; then
  REASON=""
  for e in "${ERRORS[@]}"; do
    REASON+="$e; "
  done
  echo "{\"decision\":\"block\",\"reason\":\"${REASON}\"}"
  exit 0
fi

echo '{"decision":"approve"}'
