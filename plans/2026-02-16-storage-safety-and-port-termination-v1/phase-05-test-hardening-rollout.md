## 1) Context links
- `./plans/2026-02-16-storage-safety-and-port-termination-v1/plan.md`
- `./plans/2026-02-16-storage-safety-and-port-termination-v1/research/researcher-01-report.md`
- `./plans/2026-02-16-storage-safety-and-port-termination-v1/research/researcher-02-report.md`
- `./plans/2026-02-16-storage-safety-and-port-termination-v1/scout/scout-01-report.md`
- `./MacMonitor/Tests/StorageManagementViewModelTests.swift`
- `./MacMonitor/Tests/RAMDetailsViewModelTests.swift`
- `./MacMonitor/Tests/SignalProcessTerminatorTests.swift`

## 2) Overview
- date: 2026-02-16
- description: Finalize regression coverage, timing stability, and rollout checks for both feature tracks.
- priority: P2
- implementation status: pending
- review status: pending

## 3) Key Insights
- Repository has uncommitted storage-related edits; merge-safe execution is required.
- Both features are timing-sensitive and need deterministic tests.
- Existing test suites should be extended, not replaced.

## 4) Requirements
- Preserve local uncommitted storage edits during implementation.
- Add deterministic tests for graceful timeout and force escalation paths.
- Validate summary buckets across storage and ports workflows.
- Run targeted regression suites and manual smoke scenarios.
- Testing strategy: unit tests for each branch plus manual dialog/summary verification.

## 5) Architecture
- No major runtime architecture additions.
- Add test doubles/time controls for deterministic async behavior.
- Keep rollout checklist artifacts in this plan directory.

## 6) Related code files
- modify: `./MacMonitor/Tests/StorageManagementViewModelTests.swift`
- modify: `./MacMonitor/Tests/RAMDetailsViewModelTests.swift`
- modify: `./MacMonitor/Tests/SignalProcessTerminatorTests.swift`
- create: `./MacMonitor/Tests/ListeningPortTerminationFlowTests.swift`

## 7) Implementation Steps
1. Snapshot current local storage-related diffs and keep them intact.
2. Add deterministic storage escalation tests.
3. Add deterministic ports escalation tests.
4. Run targeted test suites and stabilize timeouts/retries.
5. Run manual smoke checks for both destructive workflows.

## 8) Todo list
- [ ] Confirm no overwrite of existing local storage edits.
- [ ] Complete storage escalation coverage.
- [ ] Complete ports escalation coverage.
- [ ] Run targeted tests and capture results.
- [ ] Finish manual QA checklist.

## 9) Success Criteria
- New and modified tests pass reliably.
- Manual QA confirms graceful-first and force-second behavior in both features.
- No regression in existing storage or RAM process flows.
- Existing uncommitted local changes remain preserved.

## 10) Risk Assessment
- Risk: flaky tests due to polling windows.
- Risk: merge conflicts with current local storage edits.
- Mitigation: deterministic timing controls and phase-scoped changes.

## 11) Security Considerations
- Verify destructive warnings before all force actions.
- Verify protected processes/apps cannot be force-killed via new flows.
- Verify summaries do not hide skipped/failed destructive actions.

## 12) Next steps
- Implementation can begin phase-by-phase with review checkpoints after each phase.
