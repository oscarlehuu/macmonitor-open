# Researcher 01 Report: Policy Persistence and Data Contracts

## Goal
Define a low-friction persistence design for per-app RAM policies that survives app restarts and matches macOS app-data conventions.

## Findings
- Existing persisted settings use `UserDefaults` via `SettingsStore`, but that model is too flat for many policy rows and event history.
- Project bundle id is `com.oscar.macmonitor`, so the standard data root is `~/Library/Application Support/com.oscar.macmonitor/`.
- Current codebase has no SQLite layer; introducing DB infra now increases risk/scope for v1.
- Swift `Codable` + atomic file write is enough for policy durability in this release.

## Recommended v1 Storage Shape
1. `~/Library/Application Support/com.oscar.macmonitor/ram-policies.json`
2. `~/Library/Application Support/com.oscar.macmonitor/ram-policy-events.jsonl`

## Recommended Policy Model (v1)
- `id: UUID`
- `bundleID: String`
- `displayName: String`
- `limitMode: percent | absoluteGB`
- `percentValue: Double?`
- `absoluteGBValue: Double?`
- `triggerMode: immediate | sustained | both`
- `sustainedSeconds: Int` (default 15)
- `notifyCooldownSeconds: Int` (default 300)
- `enabled: Bool`
- `updatedAt: Date`

## Recommended Event Model (v1)
- `timestamp: Date`
- `bundleID: String`
- `displayName: String`
- `observedBytes: UInt64`
- `thresholdBytes: UInt64`
- `triggerKind: immediate | sustained`
- `action: notify`
- `message: String`

## Tradeoff Notes
- JSON files win for speed-to-ship and readability.
- SQLite can be added later if row counts or query complexity grow.

## Sources
- `./MacMonitor/Sources/Features/Settings/SettingsStore.swift`
- `./project.yml`

## Unresolved Questions
- Should policy edits be serialized with a dedicated actor or a private dispatch queue?
