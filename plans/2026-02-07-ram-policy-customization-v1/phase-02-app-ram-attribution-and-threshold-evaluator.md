# Phase 02: App RAM Attribution and Threshold Evaluator

## Context links
- Parent plan: `./plan.md`
- Dependencies: `./phase-01-policy-domain-and-persistence-foundation.md`
- Docs: `./research/researcher-02-report.md`, `./scout/scout-01-report.md`

## Overview
- Date: 2026-02-07
- Description: compute per-app RAM totals and evaluate `%`/`GB` policy thresholds.
- Priority: P1
- Implementation status: pending
- Review status: pending

## Key Insights
- Existing collector already provides process rows and periodic refresh cadence.
- App-level policy requires deterministic process-to-app attribution.

## Requirements
- Aggregate total RAM for each app across main + helper processes.
- Attribute rows to app by bundle id when possible.
- Calculate threshold bytes from `%` or `GB` policy mode.
- Evaluate immediate and sustained rule paths.
- Support trigger mode selection (`immediate`, `sustained`, `both`).

## Architecture
- Add `Core/RAMPolicy/AppRAMUsageSnapshot.swift` (per-app totals at sample time).
- Add `Core/RAMPolicy/AppRAMAttributor.swift` (process rows -> app buckets).
- Add `Core/RAMPolicy/RAMPolicyEvaluator.swift` (threshold checks + sustained state memory).
- Track sustained windows in evaluator state keyed by policy id.

## Related code files
- `MacMonitor/Sources/Core/Processes/LibprocProcessListCollector.swift`
- `MacMonitor/Sources/Core/Processes/ProcessMemoryItem.swift`
- `MacMonitor/Sources/Core/Metrics/MetricsEngine.swift`

## Implementation Steps
1. Build attribution service with bundle-id-first grouping.
2. Add evaluator for threshold conversion and breach decisioning.
3. Add clock-injected sustained window logic for deterministic tests.
4. Expose evaluator output as structured events for enforcement phase.

## Todo list
- [ ] Implement app grouping and byte summation.
- [ ] Implement threshold conversion for `%` and `GB`.
- [ ] Implement immediate/sustained/both decisions.
- [ ] Add unit tests for trigger correctness and edge values.

## Success Criteria
- Cursor-like app with helpers reports single combined total.
- Threshold output is consistent for `%` and `GB` modes.
- Sustained mode only triggers after configured continuous breach duration.

## Risk Assessment
- Some processes cannot be mapped to bundle id reliably.
- Process churn can create temporary attribution gaps.

## Security Considerations
- This phase reads process metadata only.
- No process signaling or privilege escalation path.

## Next steps
- Integrate evaluator outputs with notify-only enforcement and logs.
