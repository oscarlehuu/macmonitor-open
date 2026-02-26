## 1) Context links
- `./plans/2026-02-16-storage-safety-and-port-termination-v1/plan.md`
- `./plans/2026-02-16-storage-safety-and-port-termination-v1/research/researcher-02-report.md`
- `./plans/2026-02-16-storage-safety-and-port-termination-v1/scout/scout-01-report.md`
- `./MacMonitor/Sources/Core/Processes/ProcessTerminating.swift`
- `./MacMonitor/Sources/Features/RAMDetails/RAMDetailsViewModel.swift`
- `./MacMonitor/Sources/Features/RAMDetails/RAMDetailsView.swift`

## 2) Overview
- date: 2026-02-16
- description: Add two-step Ports termination flow: graceful SIGTERM then optional force SIGKILL for survivors.
- priority: P2
- implementation status: pending
- review status: pending

## 3) Key Insights
- Selected ports must normalize to a unique PID set before terminate.
- Existing termination mapping already handles `EPERM`, `ESRCH`, and protected skips.
- Force kill must be second-step only.

## 4) Requirements
- Convert selected port rows to unique allowed PID set.
- Stage 1: graceful terminate (`SIGTERM`) with 10s total wait and 250ms polling cadence.
- Recheck remaining alive PIDs after graceful pass.
- Stage 2: one explicit batch `Force Kill Remaining` (`SIGKILL`) confirmation for all survivors.
- If force is declined, report survivors as skipped.
- Testing strategy: dedupe, escalation, decline-path, and summary tests.

## 5) Architecture
- Extend/wrap process terminator to support signal choice without logic duplication.
- Keep `RAMDetailsViewModel` as orchestration point for two-stage dialogs.
- Reuse existing `ProcessProtectionPolicy` unchanged.

## 6) Related code files
- modify: `./MacMonitor/Sources/Core/Processes/ProcessTerminating.swift`
- modify: `./MacMonitor/Sources/Features/RAMDetails/RAMDetailsViewModel.swift`
- modify: `./MacMonitor/Sources/Features/RAMDetails/RAMDetailsView.swift`
- modify: `./MacMonitor/Tests/SignalProcessTerminatorTests.swift`
- modify: `./MacMonitor/Tests/RAMDetailsViewModelTests.swift`

## 7) Implementation Steps
1. Add selected-port -> PID normalization and dedupe logic.
2. Implement stage-1 graceful termination for Ports mode.
3. Add alive recheck and conditional stage-2 force confirmation.
4. Execute force path only after explicit second confirmation.
5. Update summary text with PID buckets and selected-port context.
6. Add tests for mixed protected/unprotected and force-decline branches.

## 8) Todo list
- [ ] Add PID dedupe for selected ports.
- [ ] Implement graceful-first termination path in Ports mode.
- [ ] Add second-step force dialog for survivors only.
- [ ] Extend summary buckets and copy.
- [ ] Add escalation tests.

## 9) Success Criteria
- Ports termination always starts graceful.
- Force dialog appears only when graceful leaves survivors.
- Protection policy blocks protected PIDs in both stages.
- Tests validate dedupe and outcome reporting.

## 10) Risk Assessment
- Risk: users may kill shared local dev services unintentionally.
- Risk: targets may exit between checks and actions.
- Mitigation: clear warnings and live rechecks before force.

## 11) Security Considerations
- Keep protected/system process denylist enforcement intact.
- Limit kill scope to explicit user-selected port owners.
- Maintain explicit destructive confirmation before SIGKILL.

## 12) Next steps
- Execute phase 5 for regression hardening and rollout readiness.
