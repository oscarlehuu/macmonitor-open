## 1) Context links
- `./plans/2026-02-16-storage-safety-and-port-termination-v1/plan.md`
- `./plans/2026-02-16-storage-safety-and-port-termination-v1/research/researcher-01-report.md`
- `./plans/2026-02-16-storage-safety-and-port-termination-v1/scout/scout-01-report.md`
- `./MacMonitor/Sources/Features/StorageManagement/StorageManagementView.swift`
- `./MacMonitor/Sources/Features/StorageManagement/StorageManagementViewModel.swift`
- `./MacMonitor/Sources/Core/Storage/StorageManagementModels.swift`

## 2) Overview
- date: 2026-02-16
- description: Add second-step force-quit confirmation and richer storage deletion outcomes.
- priority: P2
- implementation status: pending
- review status: pending

## 3) Key Insights
- Force quit must be explicit and only after graceful timeout.
- Current delete summary is too coarse for running/declined-force outcomes.
- Batch handling is fine for v1 if per-item reasons are preserved.

## 4) Requirements
- Show second destructive dialog only for apps still running after graceful timeout.
- Use one batch dialog for all still-running selected apps.
- Dialog copy explicitly warns about unsaved work loss.
- If user declines force, skip those app bundles and continue other deletions.
- Add explicit result bucket(s) for still-running/force-declined outcomes.
- Testing strategy: view-model tests for force-accept, force-decline, mixed selections.

## 5) Architecture
- Extend storage delete state machine: initial confirm -> graceful pass -> optional force confirm -> delete eligible -> summarize.
- Keep force scope limited to items flagged still-running.
- Expand storage result model for accurate reason reporting.

## 6) Related code files
- modify: `./MacMonitor/Sources/Features/StorageManagement/StorageManagementView.swift`
- modify: `./MacMonitor/Sources/Features/StorageManagement/StorageManagementViewModel.swift`
- modify: `./MacMonitor/Sources/Core/Storage/StorageManagementModels.swift`
- modify: `./MacMonitor/Tests/StorageManagementViewModelTests.swift`

## 7) Implementation Steps
1. Add UI state for second-stage force confirmation dialog.
2. Wire force action only to timed-out app targets.
3. Filter delete list when force is declined.
4. Extend summary model/text for still-running and declined-force reasons.
5. Add tests for both branches and summary counts.

## 8) Todo list
- [ ] Implement second-stage force dialog with explicit warning copy.
- [ ] Gate force path strictly behind graceful timeout.
- [ ] Add per-item reason for still-running/declined force.
- [ ] Preserve compatibility with current local storage edits.
- [ ] Update tests to lock escalation behavior.

## 9) Success Criteria
- Force dialog appears only after graceful timeout.
- Declining force never blocks deletion of other eligible items.
- Summary clearly reports deleted vs skipped-running counts.
- Escalation-path tests pass.

## 10) Risk Assessment
- Risk: race between prompt and app exiting naturally.
- Risk: confusing copy in destructive step.
- Mitigation: live recheck before force and before delete.

## 11) Security Considerations
- Force remains opt-in and selected-target only.
- Destructive warning is explicit and second-step only.
- No bypass of protection rules for non-selected targets.

## 12) Next steps
- Start phase 3 to build Ports mode collector/model.
