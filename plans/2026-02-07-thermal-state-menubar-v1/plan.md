---
title: "MacMonitor v1: Apple Silicon Menu Bar Thermal State"
description: "Detailed implementation plan to ship menu bar system monitor with thermal state first and release installer script."
status: pending
priority: P2
effort: 10d
branch: no-git-branch
tags: [macos, swiftui, menubar, thermal-state, release]
created: 2026-02-07
---

# Overview
Goal: ship open-source macOS Apple Silicon menu bar app with RAM, storage, and thermal state; widget later.

## Decisions locked
- Platform: Apple Silicon only.
- Distribution: non-App-Store open-source.
- Heat v1: `NSProcessInfoThermalState`.
- Update cadence: every few mins.
- Release ops: manual install script in v1, Sparkle candidate in v1.1.

## Phases
- [Phase 01 - Project bootstrap + menu bar shell](./phase-01-project-bootstrap-menubar-shell.md) - pending (0%)
- [Phase 02 - Metrics engine + thermal state domain](./phase-02-metrics-engine-thermal-domain.md) - pending (0%)
- [Phase 03 - Popover UI, settings, persistence](./phase-03-ui-settings-persistence.md) - pending (0%)
- [Phase 04 - Packaging, installer script, release workflow](./phase-04-release-packaging-installer.md) - pending (0%)
- [Phase 05 - Widget-ready shared snapshot layer](./phase-05-widget-ready-shared-snapshot.md) - pending (0%)

## Dependencies
- Apple Developer ID setup for signing/notarization before public release.
- GitHub Actions or local release checklist for reproducible artifacts.

## Exit criteria
- Menu bar app launches at login (optional toggle), updates stats on configured interval.
- Thermal state changes are reflected reliably.
- Installer script upgrades existing app safely with backup + verification.

## Report index
- Research: `./research/researcher-01-report.md`, `./research/researcher-02-report.md`
- Scout: `./scout/scout-01-report.md`
- Synthesis: `./reports/01-solution-synthesis.md`
