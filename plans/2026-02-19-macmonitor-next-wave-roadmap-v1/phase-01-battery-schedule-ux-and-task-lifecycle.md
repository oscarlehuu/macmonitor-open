# Context links
- Parent plan: `./plan.md`
- Inputs: `./research/researcher-01-report.md`, `./scout/scout-01-report.md`
- Core files: `./MacMonitor/Sources/Features/Automation/BatteryScheduleCoordinator.swift`, `./MacMonitor/Sources/Features/Battery/BatteryScreenView.swift`

# Overview
- Date: 2026-02-19
- Description: expose existing battery schedule backend via in-app schedule creation/list/cancel UX.
- Priority: P1
- Implementation status: implemented-local
- Review status: pending-verification

# Key Insights
- Scheduler infra and persistence already exist.
- Current battery UI has no schedule management surface.
- Lowest-risk high-visibility step in roadmap.

# Requirements
- Add schedule section in battery screen.
- Support one-shot tasks for: set limit, top up, discharge, pause charging.
- Show pending tasks sorted by execution time.
- Allow cancellation for pending tasks.
- Show last execution summary and last failure reason.

# Architecture
- Reuse `BatteryScheduleCoordinator` as source of truth.
- Add lightweight view model adapter for draft task creation and validation.
- Keep scheduling local persistence in existing `BatteryScheduleStore`.
- Keep command execution path unchanged (`BatteryPolicyCoordinator.applyScheduledAction`).

# Related code files
- Modify: `./MacMonitor/Sources/Features/Battery/BatteryScreenView.swift`
- Modify: `./MacMonitor/Sources/Core/DI/AppContainer.swift`
- Modify: `./MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- Create: `./MacMonitor/Sources/Features/Automation/BatteryScheduleViewModel.swift`
- Modify tests: `./MacMonitor/Tests/BatteryScheduleCoordinatorTests.swift`

# Implementation Steps
1. Add `BatteryScheduleViewModel` with draft state, validation, and task formatting helpers.
2. Inject schedule view model into popover root from `AppContainer`.
3. Render schedule editor + pending list in `BatteryScreenView`.
4. Wire create/cancel actions to coordinator.
5. Add unit tests for validation and task ordering display logic.

# Todo list
- [ ] Define v1 schedule input UX (date/time picker + action selector).
- [ ] Add guardrails for invalid times and out-of-range discharge/limit values.
- [ ] Add empty-state, loading-state, and failure-state copy.
- [ ] Add analytics/log hooks for schedule create/cancel/execute outcomes.

# Success Criteria
- User can create and cancel battery schedule tasks without restart.
- Pending tasks survive relaunch and process after wake.
- Task execution outcomes are visible in status UI.

# Risk Assessment
- Risk: user schedules conflicting actions close together.
- Mitigation: coalesce by existing queue engine rules and clearly show final queue state.

# Security Considerations
- No new privileged surface; all commands still flow through existing helper control path.
- Validate action bounds before task persistence.

# Next steps
- After phase completion, use real schedule usage to shape recurring-task design.
