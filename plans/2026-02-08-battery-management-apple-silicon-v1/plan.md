---
title: "MacMonitor v1.3: Apple Silicon Battery Management (All-Free)"
description: "Hard plan to ship battery control and automation on Apple Silicon with privileged helper architecture, with advanced sleep/calibration features deferred."
status: in_progress
priority: P1
effort: 18d
branch: codex/battery-implementation-brainstorm
tags: [feature, macos, battery, power-management, helper, xpc]
created: 2026-02-08
---

# Overview
Goal: add battery management to MacMonitor with no Free/Pro split, all features free, Apple Silicon only.

## Decisions locked
- Platform: Apple Silicon only.
- Architecture: privileged helper + XPC is approved.
- Packaging: one all-free app; no paywall or feature gating.
- Delivery strategy: Group 1 now, Group 2 later.

## Scope partition
- Group 1 (now): charge limiter, manual+automatic discharge, top up, sailing mode, heat protection, schedule, power flow telemetry, live status icons, Shortcuts, fast user switching support, stop charging when app closed.
- Group 2 (later): stop charging when sleeping, disable sleep until charge limit, calibration mode automation, hardware battery percentage refinement, optional MagSafe LED control.

## Phases
- [Phase 01 - Battery domain and read-only telemetry pipeline](./phase-01-battery-domain-and-readonly-telemetry-pipeline.md) - completed (100%)
- [Phase 02 - Privileged helper and XPC control backend](./phase-02-privileged-helper-and-xpc-control-backend.md) - in_progress (55%)
- [Phase 03 - Core control modes for Group 1](./phase-03-core-control-modes-for-group-1.md) - in_progress (85%)
- [Phase 04 - UX, schedule, shortcuts, and live status](./phase-04-ux-schedule-shortcuts-and-live-status.md) - in_progress (90%)
- [Phase 05 - Hardening for sleep/wake/reboot/user-switch](./phase-05-hardening-for-sleep-wake-reboot-user-switch.md) - in_progress (70%)
- [Phase 06 - Deferred Group 2 features](./phase-06-deferred-group-2-features.md) - pending (0%)

## Dependencies
- Codesigning and helper installation pipeline for privileged operations.
- Stable XPC contract between app and helper.
- Model-level validation matrix across Apple Silicon generations.

## Exit criteria
- Group 1 features are functional, stable, and documented.
- No monetization gate exists in code or UX.
- Group 2 is explicitly parked with acceptance criteria and risks.

## Report index
- Research: `./research/researcher-01-report.md`, `./research/researcher-02-report.md`
- Scout: `./scout/scout-01-report.md`
- Synthesis: `./reports/01-solution-synthesis.md`

## Validation Log

### Session 1 - 2026-02-08
**Trigger:** Initial validation interview before implementation.
**Questions asked:** 4

#### Questions & Answers

1. **[Architecture]** Privileged helper install model?
   - Options: `SMJobBless` root helper (Recommended) | User-level helper only (reduced control) | External CLI dependency bridge
   - **Answer:** `SMJobBless` root helper
   - **Rationale:** Group 1 requires reliable privileged operations and first-party lifecycle integration; user-level or external-CLI approaches reduce control and reliability.

2. **[Scope/Risk]** Scheduled tasks during sleep behavior?
   - Options: Run missed task at next wake (catch-up) (Recommended) | Skip missed task | Queue all missed tasks
   - **Answer:** Queue all missed tasks, with safeguards
   - **Rationale:** Full queue semantics are accepted, but must be bounded and coalesced to avoid backlog storms after prolonged sleep/off periods.

3. **[Assumptions/Security]** Safety bounds for user charge limits (Group 1)?
   - Options: Allow `50%-95%` only (Recommended) | Allow `40%-100%` | Allow `20%-100%`
   - **Answer:** Allow `50%-95%` only
   - **Rationale:** Conservative limits reduce unsafe usage patterns and simplify policy validation in v1.

4. **[Release/Risk]** Group 1 release gate?
   - Options: Ship after one device passes full test matrix | Ship after 3 Apple Silicon generations pass matrix (Recommended) | Ship quickly, fix via patches
   - **Answer:** Ship after 3 Apple Silicon generations pass matrix
   - **Rationale:** Battery-control trust requires cross-generation confidence before release.

#### Confirmed Decisions
- Helper model: `SMJobBless` privileged helper.
- Sleep task policy: queue missed tasks with bounded + coalesced safeguards.
- Charge-limit guardrails: `50%-95%` only for Group 1.
- Release gate: validation matrix must pass on 3 Apple Silicon generations.

#### Action Items
- [x] Lock helper architecture docs and implementation steps to `SMJobBless`.
- [x] Define queue cap + coalescing rules for scheduled task catch-up.
- [x] Enforce `50%-95%` validation in policy and App Intents paths.
- [x] Update release criteria to require 3-generation matrix pass.

#### Impact on Phases
- Phase 02: hard-lock privileged helper install model to `SMJobBless`.
- Phase 03: enforce charge-limit guardrails (`50%-95%`) in validation and command pipeline.
- Phase 04: define catch-up queue semantics as bounded + coalesced.
- Phase 05: lock release gate to 3 Apple Silicon generations.
