# Scout 01 Report: Codebase Mapping for App RAM Policy Feature

## Scope
Map concrete files to implement persistent per-app RAM policies (% or GB), dual trigger modes, notify-only action, and 7-day logs.

## Confirmed Architecture
- App lifecycle: `MacMonitor/Sources/App/MacMonitorApp.swift`, `MacMonitor/Sources/App/AppDelegate.swift`
- DI root: `MacMonitor/Sources/Core/DI/AppContainer.swift`
- Global metrics loop: `MacMonitor/Sources/Core/Metrics/MetricsEngine.swift`
- Process discovery: `MacMonitor/Sources/Core/Processes/LibprocProcessListCollector.swift`
- RAM feature state/UI: `MacMonitor/Sources/Features/RAMDetails/RAMDetailsViewModel.swift`, `MacMonitor/Sources/Features/RAMDetails/RAMDetailsView.swift`
- Navigation shell: `MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift`, `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- Settings persistence baseline: `MacMonitor/Sources/Features/Settings/SettingsStore.swift`, `MacMonitor/Sources/Features/Settings/SettingsView.swift`

## Candidate New Areas
- `MacMonitor/Sources/Core/RAMPolicy/` for models, store, evaluator, notifier, monitor coordinator
- `MacMonitor/Sources/Features/RAMPolicy/` for policy list/editor view model and SwiftUI views

## Likely Modified Files
- `MacMonitor/Sources/Core/DI/AppContainer.swift`
- `MacMonitor/Sources/Core/Metrics/MetricsEngine.swift` (or adjacent coordinator wiring)
- `MacMonitor/Sources/Features/Settings/SettingsView.swift`
- `MacMonitor/Sources/Features/Popover/PopoverRootView.swift` (if route entry added)
- `MacMonitor/Sources/Features/RAMDetails/RAMDetailsView.swift` (optional jump into policy editor)

## Test Extension Points
- `MacMonitor/Tests/SettingsStoreTests.swift`
- `MacMonitor/Tests/MetricsEngineTests.swift`
- `MacMonitor/Tests/RAMDetailsViewModelTests.swift`
- New tests under `MacMonitor/Tests/` for policy store/evaluator/monitor coordinator

## Constraints
- macOS target is 14.0 (`project.yml`).
- Current codebase has no DB dependency; avoid heavy persistence additions in v1.

## Unresolved Questions
- Where should policy management UI live first: Settings only, or Settings + RAM Details shortcut?
