---
description: Security hardening specialist - auth, secrets, dependencies, web security, supply chain. Activates for security audits, vulnerability assessment, and hardening tasks.
---

# Security Hardening Skill

Complements `security-expert.md` with focused guidance on auth, secrets management,
dependency security, and web security patterns.

## 1. Auth & Secrets Management

### Secret Hygiene Rules
```
NEVER:
- Hardcode secrets in any file (even test files)
- Log secret values (even in error messages)
- Pass secrets as command-line arguments (visible in process list)
- Store secrets in git history (even if later deleted)
- Use the same token for multiple purposes

ALWAYS:
- Use GitHub repository secrets for tokens
- Rotate tokens when compromise is suspected
- Use minimum scope/permissions for each token
- Audit secret access regularly
```

### Token Isolation (Workspace Security)
| Token | Workspace | Allowed Repos | Never Use For |
|-------|-----------|--------------|---------------|
| BBVINET_TOKEN | ws-default | bbvinet/* | CIT repos |
| CIT_TOKEN | ws-cit | CIT repos | bbvinet/* |
| GITHUB_TOKEN | autopilot | lucassfreiree/autopilot | Corporate repos |
| RELEASE_TOKEN | autopilot | Release operations | Corporate repos |

### GitHub Actions Security
```yaml
# GOOD: Minimal permissions
permissions:
  contents: read
  issues: write

# BAD: Over-privileged
permissions: write-all

# GOOD: Pin third-party actions to SHA
uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1

# ACCEPTABLE: Pin official actions to major version
uses: actions/checkout@v4

# BAD: Use latest or unpinned
uses: some-org/some-action@main
```

## 2. Dependency Security

### npm (Corporate Repos — ws-default)
```bash
# Audit before deploy
npm audit --production

# Fix automatically (non-breaking)
npm audit fix

# Check for known CVEs
npm audit --json | jq '.vulnerabilities | to_entries[] | select(.value.severity == "critical")'
```

### GitHub Actions Dependencies
- Dependabot configured (`.github/dependabot.yml`) — monitors weekly
- `builds-validation-gate.yml` checks for deprecated action versions
- Pin all third-party actions to specific SHA or tag

### Supply Chain Checklist
```
- [ ] All Actions from official sources or SHA-pinned
- [ ] Dependabot alerts reviewed weekly
- [ ] No `curl | bash` in production workflows
- [ ] Docker images from trusted registries only
- [ ] Lock files committed (package-lock.json)
```

## 3. Web Security (Dashboard & API)

### Dashboard (GitHub Pages)
```
- No user input processing (static site)
- No cookies or session management
- No external API calls with secrets
- CSP headers via _headers file if needed
- All data comes from state branch (read-only)
```

### Corporate Repos (Controller/Agent API)
| Pattern | Check | Tool |
|---------|-------|------|
| XSS | Input reflected without sanitize | `sanitizeForOutput()` |
| SSRF | User input in fetch URL | `validateTrustedUrl()` |
| DoS | Unbounded loops | `MAX_RESULTS` constant |
| Injection | Template literals in SQL/queries | Parameterized queries |
| Auth bypass | Missing JWT validation | Middleware check |

### JWT Best Practices (from daianepepes-lab/claude-skills)
```
- Sign with strong secret or RS256 (never HS256 with weak key)
- Short expiry: 15min access token, 7d refresh token
- Store refresh tokens in httpOnly cookies (never localStorage)
- Validate on EVERY request — no skipping for "internal" routes
- Include iss, aud, exp, iat claims
- Controller uses: payload.scope (singular, not scopes)
- See contracts/interface-contract.json for JWT claim spec
```

### Password & Auth Hardening
```
- Hash with bcrypt (cost factor 12+) or argon2id
- Account lockout after 5 failed attempts
- Log ALL authentication events (success + failure)
- API keys: cryptographically random, hash in DB, scope permissions
- Never commit secrets to version control (even test tokens)
```

### Compliance Gate Integration
Rules 10-13 in `compliance-gate.yml` enforce:
- Rule 10: security-xss (input reflected without sanitize)
- Rule 11: security-ssrf (user input in fetch)
- Rule 12: security-dos-loop (loop without MAX_RESULTS)
- Rule 13: hardcoded-secret (secrets in patches)

## 4. Scanning Commands

```bash
# Scan for hardcoded secrets
grep -rlE "ghp_[a-zA-Z0-9]{36}|AKIA[0-9A-Z]{16}|-----BEGIN.*PRIVATE" \
  --include="*.yml" --include="*.json" --include="*.ts" --include="*.sh" .

# Scan for corporate data leaks
grep -rlE '[a-z0-9]+\.intranet\.[a-z]+\.[a-z]+' \
  --include="*.md" --include="*.yml" --include="*.json" .

# Scan for cross-contamination
grep -rlE "bbvinet|BBVINET" ops/config/workspaces/ws-cit* contracts/*cit* 2>/dev/null

# Check workflow permissions
for f in .github/workflows/*.yml; do
  echo "$(basename $f): $(grep -c 'permissions:' $f 2>/dev/null || echo 0) permission blocks"
done
```

## 5. Incident Response (Security)
```
1. CONTAIN: Revoke compromised token immediately
2. ASSESS: What was exposed? Which repos? Which workspace?
3. AUDIT: Check git log for unauthorized commits
4. FIX: Rotate all potentially compromised secrets
5. MONITOR: Watch for unauthorized access 48h
6. DOCUMENT: Create Issue with full timeline
```
