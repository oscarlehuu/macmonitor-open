# Researcher 01 Report
Date: 2026-02-16
Focus: Running-app deletion safety in Storage Manager (graceful first, explicit force fallback)

## Scope
- Validate OS-level behavior when deleting files/apps that are currently in use.
- Validate safe termination escalation sequence and user confirmation model.
- Map findings to current MacMonitor storage flow.

## Key Findings
1. Deleting a path does not mean a running process immediately stops.
- `unlink(2)` behavior: file removal can succeed while file descriptors remain open; storage is reclaimed when refs close.
- Implication: deleting an open `.app` may remove launch path but not terminate already-running instance.

2. macOS provides explicit graceful-vs-force app lifecycle controls.
- `NSRunningApplication.terminate()` for graceful quit.
- `NSRunningApplication.forceTerminate()` for explicit force path.

3. `kill(2)` supports non-destructive liveness/permission checks.
- `kill(pid, 0)` checks existence/permission without sending signal.
- Important failure cases for robust outcome mapping: `EPERM`, `ESRCH`.

4. Current MacMonitor storage delete flow does not preflight running apps.
- It immediately calls `FileManager.trashItem(...)` per target.
- Outcome model has no explicit `running/not-quit` classification.
- UX has a single generic destructive confirmation.

## Evidence in Codebase
- Storage delete loop: `./MacMonitor/Sources/Core/Storage/LocalStorageManager.swift:126`
- Immediate trash call: `./MacMonitor/Sources/Core/Storage/LocalStorageManager.swift:149`
- Outcome enum/message today: `./MacMonitor/Sources/Core/Storage/StorageManagementModels.swift:206`
- Single generic delete confirmation: `./MacMonitor/Sources/Features/StorageManagement/StorageManagementView.swift:56`

## V1 Recommendations
1. Add preflight for selected app bundles.
- Detect selected `.app` items (or app-group-selected bundle entry).
- Resolve running app instance by bundle identifier when available; fallback to bundle URL path match.

2. Graceful-first termination policy.
- Attempt app quit first.
- Wait up to ~10 seconds, polling every ~250ms.
- Optional second graceful prompt/retry at mid-timeout.

3. Explicit force fallback only after graceful failure.
- Never default-force in first dialog.
- Show second destructive confirmation only for remaining running app targets.
- If user declines force, skip those app bundles and continue deleting other items.

4. Improve outcomes and messaging.
- Add explicit result for running app not closed (or equivalent).
- Keep aggregated summary, but include clear per-item reason where possible.

## Suggested Confirmation Copy (draft)
- Stage 1: "\(AppName) is open. Quit it and move it to Trash?"
- Stage 2: "\(AppName) didn’t quit. Force Quit and move it to Trash? Unsaved work may be lost."

## Risks
- Force termination can lose unsaved user work.
- Multi-instance or helper-process apps may require careful running-state detection.

## Sources
- Apple `unlink(2)`: https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/unlink.2.html
- Apple `kill(2)`: https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/kill.2.html
- Apple `NSRunningApplication.terminate()`: https://developer.apple.com/documentation/appkit/nsrunningapplication/terminate()
- Apple `NSRunningApplication.forceTerminate()`: https://developer.apple.com/documentation/appkit/nsrunningapplication/forceterminate()
- Apple `FileManager.trashItem(...)`: https://developer.apple.com/documentation/foundation/filemanager/trashitem%28at%3Aresultingitemurl%3A%29
- Apple HIG Alerts: https://developer.apple.com/design/human-interface-guidelines/alerts

## Unresolved Questions
- Should force fallback be app-by-app or batch-by-selection in v1?
- Should helper/background companion processes be considered “same app target” for force fallback?
