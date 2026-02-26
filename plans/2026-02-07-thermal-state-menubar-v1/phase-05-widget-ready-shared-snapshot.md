# Phase 05: Widget-ready Shared Snapshot Layer

## Context links
- Parent plan: `./plan.md`
- Dependencies: Phases 01-04
- Docs: WidgetKit timeline and App Group data sharing

## Overview
- Date: 2026-02-07
- Description: prepare data contracts so widget extension can be added without rework.
- Priority: P3
- Implementation status: pending
- Review status: pending

## Key Insights
- Widget should consume snapshots; widget must not own collectors.
- App Group boundary should be introduced once core format stabilizes.

## Requirements
- Define snapshot schema versioning.
- Add App Group-backed storage adapter.
- Create timeline-friendly snapshot projection model.

## Architecture
- `Core/Domain/SnapshotSchema.swift`
- `Core/Persistence/AppGroupSnapshotStore.swift`
- `Extensions/WidgetDataProvider` (future target)

## Related code files
- `MacMonitor/Core/Domain/SnapshotSchema.swift`
- `MacMonitor/Core/Persistence/AppGroupSnapshotStore.swift`
- `MacMonitorWidget/` (future)

## Implementation Steps
1. Add schema version field and migration stubs.
2. Extract serialization into reusable module.
3. Add App Group storage adapter behind protocol.
4. Add contract tests for backward compatibility.

## Todo list
- [ ] Schema migration test fixture set.
- [ ] Widget handoff sample payload docs.
- [ ] Timeline freshness policy proposal.

## Success Criteria
- Widget extension can consume existing snapshots with zero collector duplication.
- Schema migration path defined before first widget release.

## Risk Assessment
- Premature App Group coupling can slow v1.
- Schema drift between app and widget can cause stale/broken displays.

## Security Considerations
- Keep shared container data minimal and non-sensitive.
- Validate decoded snapshot schema before render.

## Next steps
- Start widget implementation only after v1 menu bar telemetry proves stable.
