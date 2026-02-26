---
title: "MacMonitor v1.2: Per-App RAM Policy Customization (Notify-Only)"
description: "Plan to add persistent RAM policies per app with %/GB limits, immediate+sustained triggers, and 7-day event logs."
status: pending
priority: P1
effort: 5d
branch: codex/ram-customize-optimize
tags: [macos, swiftui, ram, policy, notifications, persistence]
created: 2026-02-07
---

# Overview
Goal: let users set per-app RAM policies once, persist them, and receive notify-only alerts when an app exceeds configured thresholds.

## Decisions locked
- Policy scope uses total app RAM across main and helper processes.
- User can configure thresholds as either `%` or `GB`.
- Trigger engine supports `immediate`, `sustained`, and `both`.
- Enforcement action for v1 is `notify` only (no quit/kill).
- Any app can be targeted by policy.
- Logs persist for 7 days under Application Support.

## Phases
- [Phase 01 - Policy domain and persistence foundation](./phase-01-policy-domain-and-persistence-foundation.md) - pending (0%)
- [Phase 02 - App RAM attribution and threshold evaluator](./phase-02-app-ram-attribution-and-threshold-evaluator.md) - pending (0%)
- [Phase 03 - Notify-only enforcement and event retention](./phase-03-notify-only-enforcement-and-event-retention.md) - pending (0%)
- [Phase 04 - Policy management UX in app settings](./phase-04-policy-management-ux-in-app-settings.md) - pending (0%)
- [Phase 05 - Hardening, tests, and rollout guardrails](./phase-05-hardening-tests-and-rollout-guardrails.md) - pending (0%)

## Dependencies
- Existing process memory collection remains stable on macOS 14+.
- Notification permission flow behaves predictably across first launch and upgrades.

## Exit criteria
- Policies survive relaunch without user re-entry.
- Alerts fire per configured threshold mode(s) with cooldown.
- No termination path is invoked by policy engine.
- 7-day event retention enforced automatically.

## Report index
- Research: `./research/researcher-01-report.md`, `./research/researcher-02-report.md`
- Scout: `./scout/scout-01-report.md`
- Synthesis: `./reports/01-solution-synthesis.md`
