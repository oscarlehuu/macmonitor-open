# Phase 03: Notify-Only Enforcement and Event Retention

## Context links
- Parent plan: `./plan.md`
- Dependencies: `./phase-02-app-ram-attribution-and-threshold-evaluator.md`
- Docs: `./reports/01-solution-synthesis.md`

## Overview
- Date: 2026-02-07
- Description: execute notify-only actions and persist event history with 7-day retention.
- Priority: P1
- Implementation status: pending
- Review status: pending

## Key Insights
- User explicitly chose notify-only, so policy engine must never call termination APIs.
- Alert spam control is mandatory for usability.

## Requirements
- Post local notification when breach event is actionable.
- Add per-policy cooldown to prevent repeated alerts.
- Persist events locally and prune entries older than 7 days.
- Degrade gracefully if notification permission is denied.

## Architecture
- Add `Core/RAMPolicy/RAMPolicyMonitor.swift` coordinator loop.
- Add `Core/RAMPolicy/RAMPolicyNotifier.swift` (UserNotifications adapter).
- Add `Core/RAMPolicy/RAMPolicyEventStore.swift` + `FileRAMPolicyEventStore.swift`.
- Keep policy action enum limited to `notify` in v1.

## Related code files
- `MacMonitor/Sources/Core/Metrics/MetricsEngine.swift`
- `MacMonitor/Sources/Core/DI/AppContainer.swift`
- `MacMonitor/Sources/Core/Processes/ProcessTerminating.swift`

## Implementation Steps
1. Add monitor scheduler and hook into app lifecycle start/stop.
2. Feed evaluator results into notifier and event store.
3. Add cooldown guardrails and retention pruning.
4. Ensure no calls into `ProcessTerminating` from policy path.

## Todo list
- [ ] Implement notification adapter and permission handling.
- [ ] Implement event file append + retention pruning.
- [ ] Add cooldown logic tests.
- [ ] Add integration test verifying notify-only behavior.

## Success Criteria
- Breach creates notification (when allowed) and log entry.
- Repeated breaches inside cooldown do not spam notifications.
- Events older than 7 days are removed automatically.
- Policy engine never invokes kill/terminate functions.

## Risk Assessment
- Missing notification permission can hide user-facing alerts.
- High sample frequency can cause noisy event volume if cooldown is weak.

## Security Considerations
- Notifications contain only app name and usage metrics.
- No destructive action is executed.

## Next steps
- Add policy management UI so users can configure and maintain rules.
