# Context links
- Parent plan: `./plan.md`
- Dependencies: none
- Reports: `./research/researcher-01-report.md`, `./scout/scout-01-report.md`

# Overview
- Date: 2026-02-08
- Description: Add battery snapshot domain model and collector pipeline without control actions.
- Priority: P1
- Implementation status: completed
- Review status: pending

# Key Insights
- Existing `MetricsEngine` already composes memory/storage/thermal collectors; battery can follow same pattern.
- IOKit power-source APIs provide broad battery telemetry and state-change notifications.
- Start with read-only telemetry to de-risk control features and improve observability.

# Requirements
- Add battery model to `SystemSnapshot`.
- Capture: percent, charging state, power source, time remaining, time to full, voltage, amperage, temperature, cycle count, battery health condition.
- Update snapshots on both timer and battery-change notifications.
- Persist battery history consistently with current snapshot store behavior.

# Architecture
- New `BatterySnapshot` + related enums in domain.
- New `BatteryCollecting` protocol + `BatteryCollector` implementation.
- `MetricsEngine` composes battery with existing collectors.
- `SystemSummaryViewModel` exposes battery tooltip and stale-state behavior.

# Related code files
- Modify: `MacMonitor/Sources/Core/Domain/SystemSnapshot.swift`
- Create: `MacMonitor/Sources/Core/Metrics/Collectors/BatteryCollector.swift`
- Modify: `MacMonitor/Sources/Core/Metrics/MetricsEngine.swift`
- Modify: `MacMonitor/Sources/Core/DI/AppContainer.swift`
- Modify: `MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift`
- Modify tests: `MacMonitor/Tests/MetricsEngineTests.swift`, `MacMonitor/Tests/SystemSummaryViewModelTests.swift`

# Implementation Steps
1. Extend domain with `BatterySnapshot` and helper enums.
2. Implement IOKit-based collector and notification publisher.
3. Wire collector into engine lifecycle and snapshot composition.
4. Extend tooltip + stale logic to include battery state.
5. Add tests for startup/manual/notification battery updates.

# Todo list
- [x] Define battery domain model.
- [x] Implement collector + tests for parsing/normalization.
- [x] Integrate in engine and DI.
- [x] Add view-model tests.
- [x] Validate on plugged/unplugged transitions.

# Success Criteria
- Snapshot contains non-empty battery data on Apple Silicon laptop.
- Battery changes trigger snapshot refresh.
- Existing RAM/storage/thermal behavior remains unchanged.

# Risk Assessment
- Dictionary keys vary by model or OS patch level.
- Notification cadence can be noisy; must debounce if needed.

# Security Considerations
- Read-only telemetry has low privilege impact.
- Ensure no accidental exposure of hardware serial values in logs.

# Next steps
- Continue with privileged control backend in Phase 02.
