# Scout 01 Report: Codebase Touchpoints for Battery Plan
Date: 2026-02-08

## Documentation availability check
- `docs/` directory not found in current repo.
- Planning proceeded via direct code inspection.

## Core architecture files
- `MacMonitor/Sources/Core/Domain/SystemSnapshot.swift`
- `MacMonitor/Sources/Core/Metrics/MetricsEngine.swift`
- `MacMonitor/Sources/Core/DI/AppContainer.swift`

## Existing collectors and pattern references
- `MacMonitor/Sources/Core/Metrics/Collectors/MemoryCollector.swift`
- `MacMonitor/Sources/Core/Metrics/Collectors/StorageCollector.swift`
- `MacMonitor/Sources/Core/Metrics/Collectors/ThermalCollector.swift`

## UI and settings integration points
- `MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift`
- `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- `MacMonitor/Sources/Features/MenuBar/MenuBarController.swift`
- `MacMonitor/Sources/Features/MenuBar/MenuBarDisplayFormatter.swift`
- `MacMonitor/Sources/Features/Settings/SettingsStore.swift`
- `MacMonitor/Sources/Features/Settings/SettingsView.swift`

## Lifecycle + app startup
- `MacMonitor/Sources/App/AppDelegate.swift`
- `MacMonitor/Sources/App/MacMonitorApp.swift`

## Build/project config
- `project.yml`

## Current test baselines
- `MacMonitor/Tests/MetricsEngineTests.swift`
- `MacMonitor/Tests/SystemSummaryViewModelTests.swift`
- `MacMonitor/Tests/SettingsStoreTests.swift`
- `MacMonitor/Tests/MenuBarDisplayFormatterTests.swift`

## Unresolved questions
- None for discovery; all critical integration points identified.
