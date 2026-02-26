# Researcher 02 Report: Architecture + UX Integration

## Goal
Fit RAM detail + multi-select terminate workflow into current MacMonitor architecture with minimal disruption.

## Findings
- Current dependency root is `AppContainer`, which wires collectors, `MetricsEngine`, `SnapshotStore`, and `SystemSummaryViewModel`.
- Popover navigation currently has only two screens: `summary` and `settings`.
- RAM card is already rendered in `PopoverRootView`; this is the natural entry point for “click RAM for details.”
- Existing test strategy is unit-first (`MetricsEngineTests`, `SystemSummaryViewModelTests`, formatter/store tests), so new process logic should be protocolized for mocks.

## Integration Recommendation
- Add a dedicated process feature area:
- `Core/Processes/` for models/protocols/services.
- `Features/RAMDetails/` for UI + view model.
- Extend `SystemSummaryViewModel.Screen` with `.ramDetails`.
- Add navigation method from summary screen to RAM details.

## Proposed Responsibilities
- `ProcessListCollecting`: returns top processes with memory fields + eligibility metadata.
- `ProcessProtectionPolicy`: computes `isProtected` + reason for each PID.
- `ProcessTerminating`: performs batch terminate and returns per-PID results.
- `RAMDetailsViewModel`: refresh, selection state, action enablement, action execution, and post-action summary.

## UX Requirements
- RAM details view includes:
- top summary (used/total, pressure, refresh age)
- sortable process rows with checkbox + PID + user + memory + status
- protected rows disabled with inline reason
- `Terminate Selected (N)` button with confirmation
- partial-result summary after action

## Testing Focus
- Policy matrix tests for protected/allowed decisions.
- Termination service tests for `EPERM`, `ESRCH`, and mixed-batch outcomes.
- View model tests for selection, enable/disable logic, and refresh lifecycle.
- Regression tests for summary/settings navigation integrity.

## Sources
- `./MacMonitor/Sources/Core/DI/AppContainer.swift`
- `./MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift`
- `./MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- `./MacMonitor/Sources/Core/Metrics/MetricsEngine.swift`
- `./MacMonitor/Tests/SystemSummaryViewModelTests.swift`

## Unresolved Questions
- Should we keep details navigation inside `SystemSummaryViewModel` or add a separate `PopoverNavigationViewModel`?
- Do we surface all processes, or only user-owned by default with a future “show system” toggle?
