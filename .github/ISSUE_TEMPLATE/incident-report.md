---
name: Incident Report
about: Report a P1/P2/P3/P4 incident in Autopilot or managed corporate pipelines
title: '[P<N>] <brief incident description>'
labels: incident
assignees: lucassfreiree
---

## Incident Classification

**Severity:**
- [ ] P1 — Control plane inoperative / deploy blocked / corporate data exposed
- [ ] P2 — Critical workflow failing / health score < 50 / lock stuck > 30 min
- [ ] P3 — Performance degradation / non-critical workflow failing / schema warning
- [ ] P4 — Improvement / optimization / documentation

**Workspace affected:**
- [ ] `ws-default` (Getronics)
- [ ] `ws-cit` (CIT)
- [ ] Control plane (all workspaces)
- [ ] `ws-socnew` / `ws-corp-1` — **requires authorization from `lucassfreiree`**

**Component:**
- [ ] `apply-source-change.yml` pipeline
- [ ] Corporate CI (Esteira de Build NPM)
- [ ] State branch (`autopilot-state`)
- [ ] Session lock
- [ ] Health score
- [ ] Other: ___

---

## Summary

<!-- One-line description of what is broken -->

## Timeline

| Time (UTC) | Event |
|---|---|
| | Incident detected |
| | First investigation |
| | Root cause identified |
| | Fix applied |
| | Resolution confirmed |

---

## Symptoms

<!-- What is broken, what error is visible, what impact is there -->

```
(paste relevant error messages or log excerpts)
```

---

## Diagnosis

### Health Score
<!-- Current: ___ / 100 -->

### Release State
<!-- status: ___ | promoted: ___ | ciResult: ___ -->

### Session Lock
<!-- agentId: ___ | expiresAt: ___ -->

### Root Cause
<!-- What specifically caused the incident -->

---

## Actions Taken

- [ ] Alert created
- [ ] Root cause identified
- [ ] Fix applied
- [ ] Resolution validated
- [ ] Lessons added to session memory

---

## Resolution

**Status:** Open / Mitigated / Resolved

**Resolution description:**

**Validated by:**

---

## Postmortem (P1/P2 only)

**What happened?**

**Why did it happen?**

**How was it detected?**

**How was it fixed?**

**How do we prevent recurrence?**

**Lessons learned (to add to session memory):**

---

## References

- Runbook: `ops/runbooks/incidents/incident-response.json`
- Skill: `.github/skills/incident-response/SKILL.md`
- Agent: `.github/agents/incident-investigator.agent.md`
