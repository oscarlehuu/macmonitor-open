# Phase 03: RAM Details UX and Navigation

## Context links
- Parent plan: `./plan.md`
- Dependencies: `./phase-01-process-memory-data-pipeline.md`, `./phase-02-protection-policy-and-batch-terminator.md`
- Docs: `./research/researcher-02-report.md`, `./reports/01-solution-synthesis.md`

## Overview
- Date: 2026-02-07
- Description: ship clickable RAM details screen with multi-select terminate workflow.
- Priority: P1
- Implementation status: pending
- Review status: pending

## Key Insights
- Existing popover already owns summary/settings route; extend same view model route enum for least churn.
- Destructive actions need explicit confirmation + visible partial-result feedback.

## Requirements
<!-- Updated: Validation Session 1 - add scope toggle and info tooltip guidance -->
- Make RAM card interactive and route to `ramDetails` screen.
- Show process table with checkbox, name, PID, user, memory, and protection state.
- Add scope control: default same-user view with optional “Show all” toggle.
- Add selection toolbar with `Terminate Selected (N)` and refresh action.
- Add `(i)` info indicator beside terminate action with tooltip clarifying “application proceeds with allowed processes only.”
- Present confirmation dialog before terminate and show post-action summary.

## Architecture
- `Features/RAMDetails/RAMDetailsViewModel.swift`: screen state + selection + commands.
- `Features/RAMDetails/RAMDetailsView.swift`: main layout.
- `Features/RAMDetails/ProcessRowView.swift`: row rendering and disabled states.
- `Features/Popover/SystemSummaryViewModel.swift`: add route + navigation methods.
- `Features/Popover/PopoverRootView.swift`: add RAM details screen branch.

## Related code files
- `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- `MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift`
- `MacMonitor/Sources/Core/Formatting/MetricFormatter.swift`
- `MacMonitor/Sources/Features/MenuBar/MenuBarController.swift`

## Implementation Steps
1. Add new screen enum case and navigation handlers.
2. Implement RAM details view model with loading/error/ready states and scope mode switching.
3. Build SwiftUI list/table with disabled protected rows.
4. Add confirmation + action summary UX, info-tooltip behavior, and back navigation.

## Todo list
- [ ] Wire RAM card tap action to details route.
- [ ] Implement RAM details screen layout.
- [ ] Implement multi-select + enable/disable logic.
- [ ] Implement confirmation and result feedback UI.

## Success Criteria
- User can open RAM details from summary and return safely.
- Multi-select terminate button reflects valid selection only.
- Protected rows are clearly non-actionable with reason labels.
- Tooltip near terminate action clearly explains allowed-only batch behavior.

## Risk Assessment
- Popover layout density could reduce readability for long process names.
- Action latency could block UI if not isolated from main actor work.

## Security Considerations
- Prevent accidental bulk termination with clear confirmation text.
- Never render protected rows as actionable, even during refresh churn.

## Next steps
- Harden with tests, tuning, and release guardrails.
