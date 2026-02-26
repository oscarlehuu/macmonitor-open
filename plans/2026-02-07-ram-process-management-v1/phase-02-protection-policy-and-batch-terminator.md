# Phase 02: Protection Policy and Batch Terminator

## Context links
- Parent plan: `./plan.md`
- Dependencies: `./phase-01-process-memory-data-pipeline.md`
- Docs: `./research/researcher-01-report.md`, `./reports/01-solution-synthesis.md`

## Overview
- Date: 2026-02-07
- Description: enforce safe, explicit process-kill policy and batch action behavior.
- Priority: P1
- Implementation status: pending
- Review status: pending

## Key Insights
- Permission errors are expected on macOS; these are product states, not exceptional crashes.
- Safety must be policy-enforced server-side (service) and not only UI-disabled.

## Requirements
<!-- Updated: Validation Session 1 - lock strict protection baseline and allowed-only batch semantics -->
- Add policy evaluator for process protection and reason codes.
- Block: current app PID, PID <= 1, system-flagged processes, non-owned UID targets, and known critical denylist names.
- Implement batch `SIGTERM` terminator with per-process result mapping.
- Return mixed outcomes without aborting whole batch.
- Enforce allowed-only execution: non-allowed targets are skipped and reported, not blocking the full batch.
- Keep MVP termination mode at `SIGTERM` only; no force-kill path in this phase.

## Architecture
<!-- Updated: Validation Session 1 - encode explicit skip semantics -->
- `Core/Processes/ProcessProtectionPolicy.swift`: rule engine.
- `Core/Processes/TerminationResult.swift`: outcome enum + detail payload.
- `Core/Processes/ProcessTerminating.swift`: batch API contract.
- `Core/Processes/SignalProcessTerminator.swift`: `kill(SIGTERM)` implementation with skip-report behavior for disallowed rows.

## Related code files
- `MacMonitor/Sources/Core/DI/AppContainer.swift`
- `MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift`
- `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- `MacMonitor/Tests/SystemSummaryViewModelTests.swift`

## Implementation Steps
1. Define protection rules and reason taxonomy.
2. Implement policy checks and expose `isProtected` on rows.
3. Implement terminator that skips protected rows and maps OS errors.
4. Add structured summary result for UI banners and logs.

## Todo list
- [ ] Create protection policy with deterministic rule order.
- [ ] Create termination result model and mapper.
- [ ] Implement batch terminator with partial success semantics.
- [ ] Add unit tests for policy matrix and error mapping.

## Success Criteria
- Protected processes are never signaled by the terminator.
- Mixed batch returns precise counts and reasoned failures.
- Mixed selection proceeds with allowed processes only and reports skipped disallowed processes.
- Tests verify self-protection and permission-denied behavior.

## Risk Assessment
- Too broad policy could block legitimate user actions.
- Too narrow policy could allow dangerous kills.

## Security Considerations
- Principle of least privilege: only same-user, allowed targets.
- Audit log messaging must avoid leaking sensitive command details.

## Next steps
- Build RAM details UI flow on top of collector + terminator.
