## 1) Context links
- `./plans/2026-02-16-storage-safety-and-port-termination-v1/plan.md`
- `./plans/2026-02-16-storage-safety-and-port-termination-v1/research/researcher-01-report.md`
- `./plans/2026-02-16-storage-safety-and-port-termination-v1/scout/scout-01-report.md`
- `./MacMonitor/Sources/Core/Storage/LocalStorageManager.swift`
- `./MacMonitor/Sources/Features/StorageManagement/StorageManagementViewModel.swift`
- `./MacMonitor/Sources/Core/DI/AppContainer.swift`

## 2) Overview
- date: 2026-02-16
- description: Add running-app preflight and graceful quit attempt before app bundle deletion.
- priority: P2
- implementation status: pending
- review status: pending

## 3) Key Insights
- `trashItem(...)` can succeed while app process still runs.
- Current storage flow has no running-app preflight.
- `NSRunningApplication.terminate()` supports the required graceful-first behavior.

## 4) Requirements
- Detect selected `.app` bundles before delete execution.
- Resolve running app by bundle ID; fallback to bundle URL/path match.
- Attempt graceful quit and wait up to 10s with 250ms polling.
- Do not expose force quit in this phase.
- Keep non-app and non-running targets on normal delete path.
- Testing strategy: add unit tests for already-closed, quits-in-time, timeout outcomes.

## 5) Architecture
- Add a storage-side coordinator service for running-app preflight and graceful wait.
- Keep `LocalStorageManager` focused on delete mechanics.
- Emit per-item preflight state for phase-2 escalation logic.

## 6) Related code files
- modify: `./MacMonitor/Sources/Features/StorageManagement/StorageManagementViewModel.swift`
- modify: `./MacMonitor/Sources/Core/DI/AppContainer.swift`
- create: `./MacMonitor/Sources/Core/Storage/RunningAppPreflightCoordinator.swift`
- modify: `./MacMonitor/Tests/StorageManagementViewModelTests.swift`

## 7) Implementation Steps
1. Preserve current local edits in storage files/tests and avoid destructive reset workflows.
2. Add app-bundle detection in the selected-item pipeline.
3. Implement running-app resolution and graceful terminate wait loop.
4. Return structured preflight state into delete orchestration.
5. Add tests for graceful-success and timeout branches.

## 8) Todo list
- [ ] Confirm selected-item app bundle identification rules.
- [ ] Implement graceful preflight coordinator.
- [ ] Inject coordinator via `AppContainer`.
- [ ] Add view-model tests for preflight behavior.
- [ ] Validate force path is unreachable in phase 1.

## 9) Success Criteria
- Running app bundles are never deleted without graceful quit attempt.
- Graceful-timeout state is emitted deterministically.
- New tests pass for graceful success and timeout.

## 10) Risk Assessment
- Risk: app matching by path may miss helper cases.
- Risk: timing checks can be flaky.
- Mitigation: deterministic polling abstraction and explicit timeout tests.

## 11) Security Considerations
- No force path in phase 1 limits data-loss risk.
- Preflight scope must stay limited to selected app bundles.
- No change to protected/system path deletion rules.

## 12) Next steps
- Feed timeout/still-running outcomes into explicit phase-2 force-fallback flow.
