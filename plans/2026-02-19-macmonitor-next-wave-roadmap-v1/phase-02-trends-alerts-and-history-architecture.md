# Context links
- Parent plan: `./plan.md`
- Inputs: `./research/researcher-01-report.md`, `./reports/01-solution-synthesis.md`
- Core files: `./MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift`, `./MacMonitor/Sources/Core/Persistence/SnapshotStore.swift`

# Overview
- Date: 2026-02-19
- Description: convert snapshot history into trend charts and configurable alert thresholds.
- Priority: P1
- Implementation status: implemented-local
- Review status: pending-verification

# Key Insights
- History is already captured and persisted.
- No current screen leverages historical signal.
- Alerting exists for RAM policy and can be generalized.

# Requirements
- Add trends screen for RAM, storage, thermal, battery over selected windows (`24h`, `7d`).
- Add alert thresholds for thermal severe/critical, storage high usage, battery health drop.
- Add settings controls for enabling/disabling each alert type.
- Keep alert rate-limited to prevent spam.

# Architecture
- Introduce `TrendWindow` and projection helpers over existing `SystemSnapshot` history.
- Refactor `SnapshotStore` to avoid full read-write per append when history grows.
- Add `SystemAlertPolicyEngine` + `SystemAlertNotifier` following RAM policy notifier pattern.

# Related code files
- Modify: `./MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift`
- Modify: `./MacMonitor/Sources/Core/Persistence/SnapshotStore.swift`
- Create: `./MacMonitor/Sources/Core/Alerts/SystemAlertPolicyEngine.swift`
- Create: `./MacMonitor/Sources/Core/Alerts/SystemAlertNotifier.swift`
- Modify: `./MacMonitor/Sources/Features/Settings/SettingsStore.swift`
- Create UI: `./MacMonitor/Sources/Features/Trends/TrendsView.swift`

# Implementation Steps
1. Define trend window domain and history sampling utilities.
2. Extend settings model with alert policy toggles and thresholds.
3. Add alert policy evaluator and notification sender with cooldown.
4. Build trends UI with lightweight chart components suitable for popover constraints.
5. Add tests for trend projection, alert thresholds, and notification cooldown.

# Todo list
- [ ] Lock retention strategy (`24h` + `7d` baseline).
- [ ] Add migration path for snapshot schema growth.
- [ ] Add stale-data guardrail in trend rendering.
- [ ] Add tests for sparse or missing history cases.

# Success Criteria
- Users can inspect recent trends without leaving app.
- Alerts fire only when thresholds are crossed and cooldown permits.
- Snapshot writes remain performant with extended retention.

# Risk Assessment
- Risk: noisy alerts reduce trust.
- Mitigation: default conservative thresholds and explicit cooldown settings.

# Security Considerations
- Use local notifications only; no outbound telemetry.
- Keep persisted trend data local to Application Support.

# Next steps
- Feed phase output into widget timeline model design.
