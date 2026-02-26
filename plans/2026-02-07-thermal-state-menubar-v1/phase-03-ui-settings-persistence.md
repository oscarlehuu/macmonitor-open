# Phase 03: UI, Settings, Persistence

## Context links
- Parent plan: `./plan.md`
- Dependencies: Phase 02
- Docs: SwiftUI settings, AppStorage/UserDefaults patterns

## Overview
- Date: 2026-02-07
- Description: implement production popover UI, preferences, and persisted snapshot history.
- Priority: P2
- Implementation status: pending
- Review status: pending

## Key Insights
- Thermal state must be visually dominant for quick glance.
- History depth should stay small (e.g., last 200 snapshots) to avoid bloat.

## Requirements
- Popover cards: RAM, Storage, Thermal state, Last update time.
- Settings: refresh interval and temperature unit toggle (`C/F`) for future compatibility.
- Persistence: lightweight JSON ring buffer for trend display and widget handoff.

## Architecture
- `Features/Popover/` for cards and summary layout.
- `Features/Settings/` for preferences panel.
- `Core/Persistence/SnapshotStore.swift` for read/write retention.

## Related code files
- `MacMonitor/Features/Popover/SystemSummaryView.swift`
- `MacMonitor/Features/Popover/ThermalCardView.swift`
- `MacMonitor/Features/Settings/SettingsView.swift`
- `MacMonitor/Core/Persistence/SnapshotStore.swift`
- `MacMonitor/Core/Formatting/MetricFormatter.swift`

## Implementation Steps
1. Build compact and expanded popover states.
2. Implement color mapping for thermal severity.
3. Add settings bindings and persistence keys.
4. Persist snapshots and prune with ring-buffer strategy.
5. Add accessibility labels and VoiceOver-friendly descriptions.

## Todo list
- [ ] Graceful empty/error states.
- [ ] Relative timestamp display and stale warning.
- [ ] Snapshot export debug action (dev-only).

## Success Criteria
- UI readable at a glance in <3 seconds.
- Settings survive relaunch.
- Trend history survives relaunch and prunes correctly.

## Risk Assessment
- Overly dense UI can reduce menu bar usability.
- Data persistence bugs may corrupt history.

## Security Considerations
- Store only local metrics; no network telemetry by default.
- No sensitive host identifiers in persisted snapshots.

## Next steps
- Finalize release packaging and scripted install/upgrade flow.
