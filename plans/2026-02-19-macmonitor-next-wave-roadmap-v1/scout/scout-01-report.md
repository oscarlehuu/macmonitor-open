# Scout 01 Report - Codebase Discovery for Next-Wave Roadmap

## Context
`codebase-summary.md`, `code-standards.md`, `system-architecture.md`, and `project-overview-pdr.md` were not found in this repository. Per workflow, direct codebase scouting was used.

## High-signal files
- App composition and dependency wiring:
  - `./MacMonitor/Sources/Core/DI/AppContainer.swift`
- Core metric pipeline:
  - `./MacMonitor/Sources/Core/Metrics/MetricsEngine.swift`
  - `./MacMonitor/Sources/Core/Metrics/Collectors/MemoryCollector.swift`
  - `./MacMonitor/Sources/Core/Metrics/Collectors/StorageCollector.swift`
  - `./MacMonitor/Sources/Core/Metrics/Collectors/BatteryCollector.swift`
  - `./MacMonitor/Sources/Core/Metrics/Collectors/ThermalCollector.swift`
- Existing battery control + automation:
  - `./MacMonitor/Sources/Core/BatteryControl/BatteryPolicyCoordinator.swift`
  - `./MacMonitor/Sources/Features/Automation/BatteryScheduleCoordinator.swift`
  - `./MacMonitor/Sources/Features/Automation/BatteryScheduleEngine.swift`
  - `./MacMonitor/Sources/Features/Automation/BatteryAppIntents.swift`
- Current UI surfaces:
  - `./MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
  - `./MacMonitor/Sources/Features/Battery/BatteryScreenView.swift`
  - `./MacMonitor/Sources/Features/Settings/SettingsView.swift`
- Persistence + history:
  - `./MacMonitor/Sources/Core/Persistence/SnapshotStore.swift`
- Prior roadmap constraints:
  - `./plans/2026-02-08-battery-management-apple-silicon-v1/phase-06-deferred-group-2-features.md`

## Key scout conclusions
1. Battery schedule infra exists but is not visible to users in current battery UI.
2. Trend history is persisted but not surfaced as charts or policy alerts.
3. Telemetry collector architecture is cleanly extensible for CPU/network additions.
4. Battery group-2 backlog exists and should be reopened with explicit gates.
5. No dedicated widget target currently present in project config.

## Unresolved questions
- Preferred release boundary: two releases vs single large release.
- Should GPU telemetry be hard requirement for next cycle.
