# Solution Synthesis: RAM Details + Safe Multi-Termination

## Decision Summary
- Build a dedicated RAM details screen inside existing popover navigation.
- Implement process collection via `libproc` wrappers, with strong error handling and conservative fallbacks.
- Enforce explicit protection policy before any terminate call.
- Execute only graceful terminate (`SIGTERM`) in v1; record per-process outcomes.

## Why This Works
- Fits current architecture: `AppContainer` DI + `SystemSummaryViewModel` route control + SwiftUI popover screens.
- Avoids scope creep: no privileged escalation, no background agent, no force-kill in MVP.
- Provides user-visible safety: protected rows disabled + reasoned feedback.

## Core Product Behavior
- User clicks RAM card.
- App opens RAM details with top memory processes.
- User selects multiple allowed rows.
- App confirms and sends terminate requests.
- App refreshes list and displays success/failure counts.

## Risk Handling
- PID churn: tolerate disappearing processes as expected race.
- Permission limits: map to clear UI result (`Permission denied`).
- Safety: block self/system/critical processes by policy, not by UI only.

## Recommended Defaults (v1)
- Show top 20 processes.
- Refresh every 5 seconds while RAM details view is visible.
- Rank by `ri_phys_footprint` first with resident fallback.

## Unresolved Questions
- Confirm whether a future release should add optional force-kill path behind an explicit advanced setting.
