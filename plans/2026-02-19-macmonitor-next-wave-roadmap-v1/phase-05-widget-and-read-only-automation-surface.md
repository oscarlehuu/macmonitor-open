# Context links
- Parent plan: `./plan.md`
- Inputs: `./reports/01-solution-synthesis.md`
- Related prior direction: `./plans/2026-02-07-thermal-state-menubar-v1/phase-05-widget-ready-shared-snapshot.md`

# Overview
- Date: 2026-02-19
- Description: add a widget target and read-only automation intents using shared snapshot contracts.
- Priority: P2
- Implementation status: implemented-local
- Review status: pending-verification

# Key Insights
- Widget was planned earlier but not yet implemented.
- Snapshot history and trends become high-value widget inputs.
- Read-only intents can improve automation safety and trust.

# Requirements
- Add `MacMonitorWidget` target with simple timeline widgets.
- Add App Group snapshot store adapter with schema versioning.
- Add read-only App Intents for full status and trend summary retrieval.
- Keep control intents and read intents clearly separated.

# Architecture
- Introduce `SnapshotSchemaVersion` and migration-aware decode.
- Add `AppGroupSnapshotStore` alongside existing local store.
- Build widget timeline provider that consumes projected snapshots only.

# Related code files
- Modify: `./project.yml`
- Create: `./MacMonitorWidget/`
- Create: `./MacMonitor/Sources/Core/Persistence/AppGroupSnapshotStore.swift`
- Modify: `./MacMonitor/Sources/Features/Automation/BatteryAppIntents.swift`

# Implementation Steps
1. Add widget target and bundle config in project spec.
2. Add shared snapshot storage adapter and schema version marker.
3. Build minimal widgets (status summary + battery trend).
4. Add read-only intents with stable payload format.
5. Add contract tests for schema compatibility.

# Todo list
- [ ] Define App Group identifier strategy.
- [ ] Lock widget freshness policy vs battery impact.
- [ ] Add fallback rendering for stale or missing data.
- [ ] Add snapshot schema migration test fixtures.

# Success Criteria
- Widget displays current + recent trend data reliably.
- Read-only intents work without opening app UI.
- Schema changes do not break widget decode path.

# Risk Assessment
- Risk: schema drift between app and widget.
- Mitigation: explicit schema version and migration tests.

# Security Considerations
- Share minimal data through App Group container.
- Keep sensitive diagnostics out of widget data model.

# Next steps
- Iterate widget variants after real-world usage feedback.
