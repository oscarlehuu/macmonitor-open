# Researcher 01 Report - Product Surface and Delivery ROI

## Objective
Define highest-ROI next implementations based on what is already shipped in code.

## Sources
- `./MacMonitor/Sources/Features/Automation/BatteryScheduleCoordinator.swift:5`
- `./MacMonitor/Sources/Core/DI/AppContainer.swift:88`
- `./MacMonitor/Sources/Features/Battery/BatteryScreenView.swift:1`
- `./MacMonitor/Sources/Features/Automation/BatteryAppIntents.swift:4`
- `./MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift:17`
- `./MacMonitor/Sources/Core/Persistence/SnapshotStore.swift:43`
- `./MacMonitor/Sources/Core/Metrics/MetricsEngine.swift:8`
- `./MacMonitor/Sources/Features/Settings/SettingsStore.swift:58`

## Findings
1. Battery automation backend is present and wired at app startup, but no first-class schedule UX exists.
- Scheduler engine and persistence exist.
- `AppContainer` starts scheduler and lifecycle catch-up.
- Battery screen currently exposes live controls/status, not schedule CRUD.

2. Command automation surface is present via App Intents.
- Intents cover set limit, pause, top-up, discharge, and get state.
- This is enough base to add richer intents without backend rewrite.

3. Trend data exists in memory/disk, but no user-facing analytics screen.
- `SystemSummaryViewModel` keeps history and loads prior snapshots.
- `SnapshotStore.append` rewrites by loading full history then saving, acceptable now but will degrade for larger retention.

4. Telemetry scope is still narrow for a monitor app.
- Current collectors: memory, storage, battery, thermal.
- Settings/menu bar mode list has no CPU/network mode today.

## Opportunity map (impact x effort)
- High impact / low-medium effort: battery schedule UI + task management.
- High impact / medium effort: trends screen + threshold alerts.
- Medium-high impact / medium effort: CPU + network collectors + menu bar modes.
- Medium impact / medium-high effort: widget + read-only intents.
- High strategic impact / high effort: deferred battery group-2 controls.

## Recommendation
Sequence by visible value and reuse:
1. Schedule UX first (reuses existing coordinator/store).
2. Trends + alerts second (reuses history pipeline).
3. CPU/network telemetry third (extends existing collector architecture).
4. Widget and expanded intents after analytics contracts settle.
5. Deferred battery group-2 after hardening gates pass.

## Unresolved questions
- Desired retention window for trends (24h only vs 7d/30d).
- Whether GPU telemetry is required in this cycle or deferred.
- Whether schedule UX should support recurrence in-app or one-shot only for v1.
