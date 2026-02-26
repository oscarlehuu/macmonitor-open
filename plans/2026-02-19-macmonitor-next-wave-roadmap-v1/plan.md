---
title: "MacMonitor Next-Wave Implementation Roadmap"
description: "Phased plan for battery scheduling UX, trends, telemetry expansion, widget surface, diagnostics, and deferred battery controls."
status: implemented-local
priority: P1
effort: 6w
branch: codex/restart-to-update-flow
tags: [feature, macos, battery, telemetry, widget, diagnostics]
created: 2026-02-19
---

# Overview
Goal: deliver next major MacMonitor capabilities in risk-managed phases, reusing existing architecture first and deferring high-risk battery controls behind explicit gates.

## Phases
| # | Phase | Status | Progress | Effort | Link |
|---|---|---|---|---|---|
| 1 | Battery schedule UX and task lifecycle | Implemented (local) | 100% | 1w | [phase-01-battery-schedule-ux-and-task-lifecycle.md](./phase-01-battery-schedule-ux-and-task-lifecycle.md) |
| 2 | Trends, alerts, and history architecture | Implemented (local) | 100% | 1.5w | [phase-02-trends-alerts-and-history-architecture.md](./phase-02-trends-alerts-and-history-architecture.md) |
| 3 | Expand telemetry (CPU/network + GPU readiness) | Implemented (local) | 100% | 1.5w | [phase-03-expand-telemetry-cpu-network-gpu-readiness.md](./phase-03-expand-telemetry-cpu-network-gpu-readiness.md) |
| 4 | Battery group-2 re-entry and delivery | Implemented (local, gated flags) | 100% | 1w | [phase-04-battery-group-2-reentry-and-delivery.md](./phase-04-battery-group-2-reentry-and-delivery.md) |
| 5 | Widget and read-only automation surface | Implemented (local) | 100% | 0.5w | [phase-05-widget-and-read-only-automation-surface.md](./phase-05-widget-and-read-only-automation-surface.md) |
| 6 | Diagnostics export and release hardening | Implemented (local) | 100% | 0.5w | [phase-06-diagnostics-export-and-release-hardening.md](./phase-06-diagnostics-export-and-release-hardening.md) |

## Dependencies
- Research: `./research/researcher-01-report.md`, `./research/researcher-02-report.md`
- Scout: `./scout/scout-01-report.md`
- Synthesis: `./reports/01-solution-synthesis.md`

## Exit criteria
- Schedule automation is user-manageable in app.
- Trend insights and alerts are reliable and configurable.
- Expanded telemetry remains performant on macOS 14+.
- Deferred battery group-2 ships only after explicit gating.
- Widget and diagnostics improve daily utility + supportability.
