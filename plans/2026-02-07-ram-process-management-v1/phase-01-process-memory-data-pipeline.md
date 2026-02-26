# Phase 01: Process Memory Data Pipeline

## Context links
- Parent plan: `./plan.md`
- Dependencies: none
- Docs: `./research/researcher-01-report.md`, `./scout/scout-01-report.md`

## Overview
- Date: 2026-02-07
- Description: build process discovery and memory ranking layer for RAM details.
- Priority: P1
- Implementation status: pending
- Review status: pending

## Key Insights
- Existing metrics engine is host-level only; per-process data needs a new service boundary.
- `libproc` gives required process granularity but needs strict defensive handling.

## Requirements
<!-- Updated: Validation Session 1 - lock footprint-first metric and scope toggle -->
- Add model representing process memory row with identity and eligibility metadata.
- Implement collector protocol + concrete service for top-N memory list.
- Normalize name/PID/user fields and memory metric for UI consumption.
- Rank processes by `ri_phys_footprint` when available; fallback to resident size when footprint is unavailable.
- Default listing scope to same-user processes and support optional “Show all” expansion mode.
- Ensure collector never crashes on vanished or inaccessible PIDs.

## Architecture
<!-- Updated: Validation Session 1 - expose scope mode and footprint-first ranking -->
- `Core/Processes/ProcessMemoryItem.swift`: immutable row model + memory metric enum.
- `Core/Processes/ProcessListCollecting.swift`: interface contract for VM tests.
- `Core/Processes/LibprocProcessListCollector.swift`: `proc_listpids` + `proc_pidinfo` wrapper.
- `Core/Processes/ProcessMemoryMetric.swift`: ranking policy (`footprintFirstFallbackResident`) and display mapping.
- `Core/Processes/ProcessScopeMode.swift`: scope options (`sameUserOnly`, `allDiscoverable`) consumed by RAM details view model.

## Related code files
- `MacMonitor/Sources/Core/DI/AppContainer.swift`
- `MacMonitor/Sources/Core/Metrics/Collectors/MemoryCollector.swift`
- `MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift`
- `MacMonitor/Tests/MetricsEngineTests.swift`

## Implementation Steps
1. Define process row/domain types and collector protocols.
2. Implement `libproc` collection with bounded buffer + per-PID safe parsing.
3. Add ranking + top-N slicing logic with deterministic tiebreakers.
4. Inject collector via `AppContainer` without altering existing metric flow.

## Todo list
- [ ] Create `Core/Processes` domain types.
- [ ] Implement `libproc` collector and fallback behavior.
- [ ] Add unit tests for sorting and PID-churn resilience.
- [ ] Wire collector into DI graph.

## Success Criteria
- Collector returns stable top-N rows from live machine data.
- Collector ranking consistently prefers footprint metric with resident fallback.
- Collector returns same-user rows by default and supports show-all mode.
- No crashes when processes exit during scan.
- Unit tests cover successful and degraded paths.

## Risk Assessment
- Private-interface drift in `libproc` response format.
- Performance overhead if refresh frequency is too high.

## Security Considerations
- Read-only process inspection in this phase.
- No shell execution and no privileged escalation paths.

## Next steps
- Implement protection policy and termination result model.
