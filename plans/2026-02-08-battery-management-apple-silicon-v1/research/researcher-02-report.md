# Researcher 02 Report: Feature Mapping + Rollout Strategy
Date: 2026-02-08

## Goal
Map requested battery features into practical “now vs later” delivery slices for MacMonitor.

## Feature mapping
- Group 1 (ship now):
  - Charge limiter
  - Manual discharge
  - Automatic discharge
  - Top up
  - Sailing mode
  - Heat protection
  - Schedule
  - Power flow and live status icons
  - Shortcuts integration
  - Fast user switching support
  - Stop charging when app closed
- Group 2 (defer):
  - Stop charging when sleeping
  - Disable sleep until charge limit
  - Calibration mode automation
  - Hardware battery percentage refinement
  - Optional MagSafe LED control

## Product constraints (locked)
- Apple Silicon only.
- Privileged helper approved.
- No monetization split; all free.

## Rollout recommendation
- Single roadmap with six phases.
- Freeze Group 1 scope and prevent creep.
- Use Group 2 as explicit deferred phase with re-entry gates.

## Validation focus
- Must test behavior across sleep/wake/reboot transitions.
- Must test user switching and helper restart reconciliation.
- Must define fallback mode when helper unavailable.

## Success metric recommendations
- Group 1 command success rate > 99% in normal runtime conditions.
- Post-wake reconciliation successful within one refresh cycle.
- No crashes from XPC/helper failures; graceful degraded mode always available.

## Sources
- `https://apphousekitchen.com/aldente-overview/`
- `https://apphousekitchen.com/aldente-overview/features/`
- `https://apphousekitchen.com/aldente-overview/pricing/`

## Unresolved questions
- Preferred UX copy for warnings about limitations during reboot/shutdown windows.
