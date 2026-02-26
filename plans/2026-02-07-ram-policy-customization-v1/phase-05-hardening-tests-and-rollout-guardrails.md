# Phase 05: Hardening, Tests, and Rollout Guardrails

## Context links
- Parent plan: `./plan.md`
- Dependencies: `./phase-01-policy-domain-and-persistence-foundation.md`, `./phase-02-app-ram-attribution-and-threshold-evaluator.md`, `./phase-03-notify-only-enforcement-and-event-retention.md`, `./phase-04-policy-management-ux-in-app-settings.md`
- Docs: `./reports/01-solution-synthesis.md`

## Overview
- Date: 2026-02-07
- Description: verify correctness, resilience, and non-destructive enforcement guarantees.
- Priority: P1
- Implementation status: pending
- Review status: pending

## Key Insights
- This feature spans persistence, periodic evaluation, and UX; regression risk is moderate.
- Must explicitly guard against accidental reuse of termination code paths.

## Requirements
- Add unit tests for policy store, evaluator, cooldown, and retention.
- Add integration tests for end-to-end notify-only loop.
- Add regression checks for existing RAM details and settings flows.
- Document rollout and fallback behavior if policy files are unreadable.

## Architecture
- Extend existing test target with RAM policy suites.
- Use fake clock and fake notifier to make timing deterministic.
- Add feature flag toggle if staged rollout is needed.

## Related code files
- `MacMonitor/Tests/MetricsEngineTests.swift`
- `MacMonitor/Tests/RAMDetailsViewModelTests.swift`
- `MacMonitor/Tests/SettingsStoreTests.swift`
- `MacMonitor/Tests/SignalProcessTerminatorTests.swift`

## Implementation Steps
1. Build deterministic test doubles for process snapshots and notifications.
2. Add coverage for `%`/`GB`, immediate/sustained/both, cooldown, and retention.
3. Add regression tests ensuring no policy path calls termination service.
4. Add release checklist and manual QA script for policy lifecycle.

## Todo list
- [ ] Add policy persistence test suite.
- [ ] Add threshold evaluator and sustained-window tests.
- [ ] Add notify-only integration tests.
- [ ] Add manual QA checklist and rollback notes.

## Success Criteria
- All new tests pass consistently on local macOS runner.
- Existing summary/settings/RAM-details behavior remains stable.
- Policy engine behavior is observable via logs and events.

## Risk Assessment
- Flaky timing-based tests if clocks/timers are not controlled.
- False positives from attribution edge cases could annoy users.

## Security Considerations
- Verify no privileged calls are introduced.
- Verify notifications do not leak private data beyond app name + memory stats.

## Next steps
- Start implementation with Phase 01 and Phase 02 in one delivery slice.
