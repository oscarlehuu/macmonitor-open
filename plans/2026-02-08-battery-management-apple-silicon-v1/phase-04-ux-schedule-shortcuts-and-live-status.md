# Context links
- Parent plan: `./plan.md`
- Dependency phase: `./phase-03-core-control-modes-for-group-1.md`
- Reports: `./research/researcher-02-report.md`

# Overview
- Date: 2026-02-08
- Description: Deliver user-facing battery experience for Group 1, including schedule and Shortcuts integration.
- Priority: P1
- Implementation status: in_progress (90%)
- Review status: pending

# Key Insights
- Current app already has robust settings/menu/popover shells; battery can fit existing UI patterns.
- Schedule and Shortcuts provide automation value without introducing monetization complexity.

# Requirements
- Add Battery screen in popover with live telemetry + control toggles.
- Extend menu bar mode options to include battery value/status.
- Add schedule tasks for limit changes, top up, discharge start/stop.
- Add App Intents for shortcuts: set limit, pause charging, top up, start discharge, get battery state.
- Expose live status icon states and textual diagnostics.
- During sleep/offline windows, queue missed tasks with bounded backlog + coalescing rules.
<!-- Updated: Validation Session 1 - schedule catch-up uses bounded/coalesced queue -->

# Architecture
- UI binds to battery view model backed by policy engine + telemetry.
- Scheduler emits intents to policy engine.
- App Intents call same command path as UI (single behavior surface).
- Scheduler backlog policy: queue-on-miss, coalesce duplicate task intents, enforce queue cap to prevent burst replay.
<!-- Updated: Validation Session 1 - explicit queue policy for missed tasks -->

# Related code files
- Modify: `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- Modify: `MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift`
- Modify: `MacMonitor/Sources/Features/Settings/SettingsView.swift`
- Modify: `MacMonitor/Sources/Features/MenuBar/MenuBarDisplayFormatter.swift`
- Modify: `MacMonitor/Sources/Features/MenuBar/MenuBarController.swift`
- Create: `MacMonitor/Sources/Features/Battery/*`
- Create: `MacMonitor/Sources/Features/Automation/BatteryScheduleEngine.swift`
- Create: `MacMonitor/Sources/Features/Automation/BatteryAppIntents.swift`

# Implementation Steps
1. Build battery screen and settings entries.
2. Extend menu bar formatter and icon renderer for battery states.
3. Implement schedule persistence and execution flow with capped/coalesced catch-up queue.
4. Implement App Intents and expose Shortcuts actions.
5. Add tests for formatter, settings persistence, and schedule logic.
<!-- Updated: Validation Session 1 - include capped/coalesced queue in schedule implementation -->

# Todo list
- [x] Add battery UI surfaces.
- [x] Add menu bar battery modes/icons.
- [x] Implement schedule engine.
- [x] Implement App Intents.
- [x] Add unit tests for automation queue behavior.

# Success Criteria
- Users can configure and monitor Group 1 fully from UI.
- Scheduled tasks execute reliably when app/helper running.
- Shortcuts actions work and reuse core policy path.

# Risk Assessment
- Scheduler behavior during sleep may drift from expected times.
- UI state may lag helper state without robust sync.

# Security Considerations
- App Intents must validate arguments before forwarding commands.
- Avoid exposing privileged operations without helper-side validation.

# Next steps
- Harden sleep/wake/reboot/user-switch behavior in Phase 05.
