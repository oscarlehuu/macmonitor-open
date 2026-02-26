# Context links
- Parent plan: `./plan.md`
- Dependency phase: `./phase-04-ux-schedule-shortcuts-and-live-status.md`
- Reports: `./research/researcher-01-report.md`, `./research/researcher-02-report.md`

# Overview
- Date: 2026-02-08
- Description: Stabilize Group 1 behavior across power lifecycle events and ship readiness matrix.
- Priority: P1
- Implementation status: in_progress (70%)
- Review status: pending

# Key Insights
- Most user trust issues come from lifecycle edge cases, not core steady-state behavior.
- Need explicit reconciliation routine on wake/login/restart/helper relaunch.

# Requirements
- Add lifecycle hooks for sleep/wake/login/logout/user switch/reboot detection.
- Reconcile desired policy vs effective helper state after every lifecycle event.
- Add telemetry + event log for command attempts and outcomes.
- Build validation matrix across at least 3 Apple Silicon generations.
- Define rollout guardrails and fallback mode (read-only monitor).
<!-- Updated: Validation Session 1 - release matrix gate locked to 3 Apple Silicon generations -->

# Architecture
- Lifecycle observer emits events to reconciliation manager.
- Reconciliation manager replays policy idempotently.
- Event store captures diagnostics for user support and bug triage.

# Related code files
- Create: `MacMonitor/Sources/Core/BatteryControl/BatteryLifecycleCoordinator.swift`
- Create: `MacMonitor/Sources/Core/BatteryControl/BatteryReconciliationManager.swift`
- Create: `MacMonitor/Sources/Core/BatteryControl/BatteryEventStore.swift`
- Modify: `MacMonitor/Sources/App/AppDelegate.swift`
- Modify: `MacMonitor/Sources/Core/DI/AppContainer.swift`
- Create tests: `MacMonitor/Tests/BatteryReconciliationManagerTests.swift`

# Implementation Steps
1. Add lifecycle event collectors and event model.
2. Implement reconciliation and idempotent policy replay.
3. Implement event logging with retention.
4. Build manual and automated test matrix.
5. Add release checklist and known-limitations docs.

# Todo list
- [x] Implement lifecycle coordinator.
- [x] Implement reconciliation manager.
- [x] Add event logging + retention.
- [ ] Execute validation matrix.
- [ ] Publish guardrails and fallback behavior.

# Success Criteria
- Group 1 policies self-heal after lifecycle disruptions.
- Recovery path succeeds without user manual intervention in normal cases.
- Known limitations are documented and surfaced.
- Release candidate is blocked until test matrix passes on 3 Apple Silicon generations.
<!-- Updated: Validation Session 1 - explicit release gate criterion -->

# Risk Assessment
- Some reboot/shutdown moments remain uncontrollable by design.
- Hardware/OS variation may produce model-specific quirks.

# Security Considerations
- Ensure logs do not leak sensitive machine identifiers.
- Keep helper diagnostics minimal and auditable.

# Next steps
- Keep Group 2 explicitly deferred in Phase 06 until Group 1 stability targets are met.
