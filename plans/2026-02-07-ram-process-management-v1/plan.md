---
title: "MacMonitor v1.1: RAM Process Details and Safe Batch Termination"
description: "Implementation plan to add clickable RAM details with process ranking, multi-select, and protected termination workflow."
status: pending
priority: P2
effort: 4d
branch: codex/ram-process-management
tags: [macos, swiftui, menubar, ram, processes, safety]
created: 2026-02-07
---

# Overview
Goal: extend the RAM card into a details workflow that surfaces top memory consumers and supports safe multi-process termination without privileged behavior.

## Decisions locked
- Navigation stays inside existing popover flow.
- Process ranking defaults to `ri_phys_footprint`, with fallback to resident size.
- Process scope defaults to same-user with an optional “Show all” toggle.
- Termination in v1 is graceful-only (`SIGTERM`); no force-kill path in MVP.
- Protected processes are non-selectable and include `self`, `pid <= 1`, system-flagged, non-owned UID, and critical denylist patterns.
- Terminate action uses partial-success semantics (“proceed with allowed only”) and shows an info tooltip near the action.
- RAM details auto-refresh cadence is 5 seconds while visible.
- Feature must work on macOS 14+ with current app architecture.

## Phases
- [Phase 01 - Process memory data pipeline](./phase-01-process-memory-data-pipeline.md) - pending (0%)
- [Phase 02 - Protection policy and batch terminator](./phase-02-protection-policy-and-batch-terminator.md) - pending (0%)
- [Phase 03 - RAM details UX and navigation](./phase-03-ram-details-ux-and-navigation.md) - pending (0%)
- [Phase 04 - Hardening, tests, and rollout guardrails](./phase-04-hardening-tests-and-rollout-guardrails.md) - pending (0%)

## Dependencies
- Stable `libproc` usage in current Xcode/macOS SDK.
- Existing `SystemSummaryViewModel` ownership of popover routes.

## Exit criteria
- Clicking RAM opens details with top memory process list.
- User can select multiple allowed rows and terminate in one action.
- Protected processes cannot be terminated and show clear reason.
- Per-action result summary is visible and deterministic.

## Report index
- Research: `./research/researcher-01-report.md`, `./research/researcher-02-report.md`
- Scout: `./scout/scout-01-report.md`
- Synthesis: `./reports/01-solution-synthesis.md`

## Validation Log

### Session 1 — 2026-02-07
**Trigger:** Initial plan validation before implementation.
**Questions asked:** 6

#### Questions & Answers

1. **[Architecture]** Memory ranking metric in RAM details?
   - Options: `pti_resident_size` first, fallback to footprint | `ri_phys_footprint` first, fallback to resident | user-toggle between both metrics in v1
   - **Answer:** `ri_phys_footprint` first, fallback to resident
   - **Rationale:** Aligns ranking with pressure-relevant memory view while preserving resilience when footprint is unavailable.

2. **[Scope]** Default process scope shown in list?
   - Options: same-user only | all discoverable processes | same-user by default + “Show all” toggle
   - **Answer:** same-user by default + “Show all” toggle
   - **Rationale:** Keeps MVP safe and actionable while preserving discoverability for advanced users.

3. **[Tradeoff]** Termination mode for v1?
   - Options: `SIGTERM` only | `SIGTERM` then optional `SIGKILL` retry | mixed `NSRunningApplication` + `kill`
   - **Answer:** `SIGTERM` only
   - **Rationale:** Reduces destructive behavior risk in first release and keeps failure semantics clear.

4. **[UX Risk]** When selection includes processes that become protected/unavailable at action time?
   - Options: auto-skip and continue batch | block entire batch | prompt “Proceed with allowed only?”
   - **Answer:** auto-skip and continue batch
   - **Custom input:** Just have (i) next to terminal, and a tooltip says that the application can only Proceed with allowed only
   - **Rationale:** Maintains one-click flow while clearly setting expectation that non-allowed items are skipped.

5. **[Performance]** Refresh interval while RAM details screen is open?
   - Options: every 5 seconds | every 2 seconds | manual refresh only
   - **Answer:** every 5 seconds
   - **Rationale:** Balances freshness and low overhead for a menu bar utility.

6. **[Safety]** Protection baseline for non-terminable processes?
   - Options: block self + pid<=1 + system-flagged + non-owned UID + critical denylist | block self + pid<=1 + non-owned UID | block only denylist
   - **Answer:** block self + pid<=1 + system-flagged + non-owned UID + critical denylist
   - **Rationale:** Enforces conservative default safety and minimizes chance of destructive mistakes.

#### Confirmed Decisions
- Ranking metric: `ri_phys_footprint` primary, resident fallback — pressure-aligned and resilient.
- Scope model: same-user default with optional “Show all” — safe default with expert visibility.
- Termination mode: `SIGTERM` only in v1 — no force-kill in MVP.
- Mixed-batch behavior: proceed with allowed-only; skipped items reported.
- Action UX: add `(i)` tooltip near terminate action to clarify allowed-only behavior.
- Refresh cadence: 5 seconds while RAM details is visible.
- Protection baseline: strict conservative rule set including system and ownership gates.

#### Action Items
- [x] Update phase-01 requirements/architecture to lock footprint-first ranking and scope toggle.
- [x] Update phase-02 requirements to lock strict protection baseline and partial-success semantics.
- [x] Update phase-03 requirements to include “Show all” toggle and `(i)` tooltip behavior near terminate action.

#### Impact on Phases
- Phase 01: lock memory metric policy (`footprint -> resident fallback`) and scope strategy (same-user default with optional show-all toggle).
- Phase 02: lock protection baseline (`self`, `pid<=1`, system-flagged, non-owned UID, denylist) and enforce allowed-only batch execution.
- Phase 03: add explicit UX requirement for info tooltip near terminate action and show-all toggle behavior.
