# Scout 01 Report: Codebase Mapping for RAM Process Feature

## Scope
Map exact code touch points for RAM details + process termination.

## Current Architecture
- App entry: `MacMonitor/Sources/App/MacMonitorApp.swift`
- DI root: `MacMonitor/Sources/Core/DI/AppContainer.swift`
- Metrics orchestration: `MacMonitor/Sources/Core/Metrics/MetricsEngine.swift`
- Popover VM: `MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift`
- Popover UI: `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- Menu bar shell: `MacMonitor/Sources/Features/MenuBar/MenuBarController.swift`

## Existing Constraints
- No process-management services currently exist.
- No dedicated RAM-detail view or screen route exists.
- `project.yml` defines macOS 14 target and Swift 6; no additional entitlements currently configured.

## Candidate New Files
- `MacMonitor/Sources/Core/Processes/ProcessMemoryItem.swift`
- `MacMonitor/Sources/Core/Processes/ProcessCollectionService.swift`
- `MacMonitor/Sources/Core/Processes/ProcessProtectionPolicy.swift`
- `MacMonitor/Sources/Core/Processes/ProcessTerminationService.swift`
- `MacMonitor/Sources/Features/RAMDetails/RAMDetailsViewModel.swift`
- `MacMonitor/Sources/Features/RAMDetails/RAMDetailsView.swift`

## Likely Modified Files
- `MacMonitor/Sources/Core/DI/AppContainer.swift`
- `MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift`
- `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- `project.yml` (only if folder/source inclusion changes are required)

## Test Extension Points
- Add tests near:
- `MacMonitor/Tests/SystemSummaryViewModelTests.swift`
- `MacMonitor/Tests/MetricsEngineTests.swift`
- new process service tests under `MacMonitor/Tests/`

## Unresolved Questions
- Which metric is final for ranking in v1 (`footprint` vs `resident`)?
- Do we allow force terminate in MVP or only graceful terminate?
