# Phase 04: Hardening, Tests, and Rollout Guardrails

## Context links
- Parent plan: `./plan.md`
- Dependencies: `./phase-03-ram-details-ux-and-navigation.md`
- Docs: `./scout/scout-01-report.md`, `./reports/01-solution-synthesis.md`

## Overview
- Date: 2026-02-07
- Description: stabilize edge cases, complete test coverage, and define release safeguards.
- Priority: P2
- Implementation status: pending
- Review status: pending

## Key Insights
- This feature touches destructive behavior, so validation quality is as important as functionality.
- Existing project already values unit testing; extend that pattern first.

## Requirements
- Add full unit coverage for collector/policy/terminator/view model behavior.
- Validate navigation regressions in existing summary/settings paths.
- Add performance guardrails for refresh cadence when RAM details is visible.
- Document QA matrix for permission-denied and protected-process flows.

## Architecture
- Extend test target with:
- `ProcessListCollectorTests.swift`
- `ProcessProtectionPolicyTests.swift`
- `ProcessTerminatorTests.swift`
- `RAMDetailsViewModelTests.swift`
- Optional fixture helpers for fake process rows and failure injection.

## Related code files
- `MacMonitor/Tests/MetricsEngineTests.swift`
- `MacMonitor/Tests/SystemSummaryViewModelTests.swift`
- `MacMonitor/Tests/MetricFormatterTests.swift`
- `Makefile`
- `README.md`

## Implementation Steps
1. Add deterministic mocks/fakes for process list and termination services.
2. Write behavioral tests for selection rules and mixed-result batches.
3. Run full test suite and tune refresh throttling if required.
4. Update README with user-facing safety behavior and limitations.

## Todo list
- [ ] Add new process-domain unit tests.
- [ ] Add RAM details view model tests.
- [ ] Verify regression coverage for existing popover features.
- [ ] Update docs for kill-safety and limitation notes.

## Success Criteria
- All new tests pass and cover core failure paths.
- No regression in existing summary/settings behavior.
- Documentation reflects actual safety and permission limitations.

## Risk Assessment
- Incomplete mocks could mask real-world permission edge cases.
- Over-frequent refresh could increase CPU impact for a menu bar app.

## Security Considerations
- Ensure test doubles never normalize unsafe behavior as acceptable.
- Reconfirm blocked-process policy before release tag.

## Next steps
- Execute implementation phase-by-phase via `/cook` in a fresh context.
