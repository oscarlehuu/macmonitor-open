---
title: "Storage Safety and Port Termination v1 Plan"
description: "Add graceful-then-force termination flows for app deletion and RAM Ports mode."
status: pending
priority: P2
effort: 22h
branch: codex/restart-to-update-flow
tags: [feature, macos, storage, ram, process-safety]
created: 2026-02-16
---

# Storage Safety and Port Termination v1

## Overview
Implement two safety-first features: Storage Manager must gracefully quit running apps before trashing bundles, and RAM Details must add a Ports mode (TCP LISTEN only) with graceful-to-force process termination.

## V1 Decisions
- Ports mode includes TCP `LISTEN` only.
- Force quit/kill is never first step.
- Reuse existing protection policy and termination summary patterns.
- Preserve and integrate with existing uncommitted storage file/test edits.

## Validation Decisions (2026-02-16)
- Storage force fallback uses one batch dialog for all still-running selected apps.
- Ports mode shows all TCP `LISTEN` rows, including protected/non-selectable with reason.
- Graceful timeout is 10s total with 250ms polling before force fallback.
- Ports force fallback uses one batch action for all remaining eligible PIDs.
- If force fallback is declined, continue operation for other eligible targets and skip only force-needed survivors.

## Phases
| # | Phase | Status | Progress | Effort | Link |
|---|---|---|---|---|---|
| 1 | Storage preflight + graceful quit | Pending | 0% | 4h | [phase-01-storage-preflight-graceful-quit.md](./phase-01-storage-preflight-graceful-quit.md) |
| 2 | Storage force fallback + results | Pending | 0% | 4h | [phase-02-storage-force-fallback-results.md](./phase-02-storage-force-fallback-results.md) |
| 3 | Ports mode + TCP LISTEN collector | Pending | 0% | 5h | [phase-03-ports-mode-tcp-listen-collector.md](./phase-03-ports-mode-tcp-listen-collector.md) |
| 4 | Ports termination escalation UX | Pending | 0% | 5h | [phase-04-ports-termination-escalation-ux.md](./phase-04-ports-termination-escalation-ux.md) |
| 5 | Test hardening + rollout readiness | Pending | 0% | 4h | [phase-05-test-hardening-rollout.md](./phase-05-test-hardening-rollout.md) |

## Dependencies
- `./plans/2026-02-16-storage-safety-and-port-termination-v1/research/researcher-01-report.md`
- `./plans/2026-02-16-storage-safety-and-port-termination-v1/research/researcher-02-report.md`
- `./plans/2026-02-16-storage-safety-and-port-termination-v1/scout/scout-01-report.md`
- `./plans/2026-02-16-storage-safety-and-port-termination-v1/reports/01-solution-synthesis.md`
- `./plans/2026-02-16-storage-safety-and-port-termination-v1/reports/02-plan-validation.md`
