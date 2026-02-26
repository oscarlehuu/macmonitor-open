# Phase 01: Policy Domain and Persistence Foundation

## Context links
- Parent plan: `./plan.md`
- Dependencies: none
- Docs: `./research/researcher-01-report.md`, `./scout/scout-01-report.md`

## Overview
- Date: 2026-02-07
- Description: establish RAM policy model and persistent storage in Application Support.
- Priority: P1
- Implementation status: pending
- Review status: pending

## Key Insights
- Existing persistence is `UserDefaults`; complex policy rows and event retention need file-based storage.
- v1 should avoid introducing database infrastructure.

## Requirements
- Persist policy records under `~/Library/Application Support/com.oscar.macmonitor/`.
- Support both threshold input modes: `%` and `GB`.
- Support trigger mode values: `immediate`, `sustained`, `both`.
- Include enabled/disabled state and timestamps.
- Use atomic write and safe read-fallback behavior.

## Architecture
- Add `Core/RAMPolicy/RAMPolicy.swift` (domain model + validation).
- Add `Core/RAMPolicy/RAMPolicyStore.swift` protocol.
- Add `Core/RAMPolicy/FileRAMPolicyStore.swift` JSON persistence adapter.
- Add `Core/RAMPolicy/AppDataDirectory.swift` helper for stable data root resolution.

## Related code files
- `MacMonitor/Sources/Features/Settings/SettingsStore.swift`
- `MacMonitor/Sources/Core/DI/AppContainer.swift`

## Implementation Steps
1. Define codable models for policy and thresholds.
2. Implement store load/save/list/update/delete APIs with atomic writes.
3. Add migration-safe defaults when file missing or partially invalid.
4. Wire store instance through `AppContainer`.

## Todo list
- [ ] Define policy schema and validation constraints.
- [ ] Implement file store and directory bootstrap.
- [ ] Add unit tests for read/write and corruption fallback.
- [ ] Add lightweight telemetry/logging for store failures.

## Success Criteria
- User-created policies survive app relaunch.
- Invalid file content does not crash app.
- Policy CRUD behaves deterministically in tests.

## Risk Assessment
- Concurrent writes can clobber file if access is not serialized.
- Schema evolution can break decoding without versioning discipline.

## Security Considerations
- Store only local non-sensitive metadata.
- Ensure file path is app-owned Application Support location.

## Next steps
- Build app-level RAM attribution and threshold evaluator.
