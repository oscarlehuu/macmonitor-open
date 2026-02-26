# Researcher 02 Report
Date: 2026-02-16
Focus: Terminate-by-port architecture in RAM details (graceful then optional force)

## Scope
- Determine reliable macOS approach for listing listening ports + owning PIDs.
- Define safe kill flow and dedupe strategy for selected ports.
- Map approach onto existing MacMonitor process protection/termination modules.

## Key Findings
1. `lsof` is pragmatic for port-to-PID mapping on macOS.
- Supports internet socket filtering and TCP state filtering (LISTEN).
- Supports PID-centric output mode for efficient target derivation.

2. `netstat` is useful for socket state visibility but not ideal as sole source for PID ownership in this UX.
- For this feature, port-owner mapping is the primary requirement.

3. Port selection maps to process termination, not socket-level termination.
- One PID can own multiple selected ports.
- Selected ports must be normalized to unique PIDs before kill attempts.

4. Existing MacMonitor modules already fit most kill-by-port needs.
- Protection policy exists and should be reused unchanged.
- Terminator maps `SIGTERM` outcomes (`EPERM`, `ESRCH`, generic fail) and skip-protected behavior.
- RAM details UI already has confirmation and termination summary patterns.

## Evidence in Codebase
- Process collection baseline: `./MacMonitor/Sources/Core/Processes/LibprocProcessListCollector.swift:16`
- Protection policy reuse candidate: `./MacMonitor/Sources/Core/Processes/ProcessProtectionPolicy.swift:66`
- SIGTERM outcome mapping: `./MacMonitor/Sources/Core/Processes/ProcessTerminating.swift:65`
- Current RAM terminate flow: `./MacMonitor/Sources/Features/RAMDetails/RAMDetailsViewModel.swift:149`
- Current scope segment UI (candidate for extra tab): `./MacMonitor/Sources/Features/RAMDetails/RAMDetailsView.swift:319`

## V1 Recommendations
1. Add dedicated port collector module.
- Use single snapshot command execution per refresh cycle.
- Limit v1 to TCP LISTEN for clarity and predictable UX.

2. Introduce port-domain model.
- Fields: protocol, port, pid, processName, user, protectionReason.
- Derived states: selectable/blocked; blocked reason from protection policy.

3. Selection normalization.
- Convert selected ports -> owning PID set.
- Deduplicate before terminate actions and summary generation.

4. Two-step termination UX.
- Stage 1: graceful terminate (`SIGTERM`) for allowed PIDs.
- Recheck remaining alive PIDs after short wait.
- Stage 2: explicit confirm for `Force Kill Remaining` (`SIGKILL`).

5. Result summary should stay PID-based.
- Buckets: terminated, skipped protected, permission denied, not found, failed.
- Secondary text may mention selected-port count vs unique-PID count.

## Risks
- Parsing shell output can drift across OS variants; parser tests required.
- Users may unintentionally kill shared dev services (DB/proxy), so copy must be explicit.

## Sources
- `lsof(8)`: https://www.manpagez.com/man/8/lsof/
- `netstat(1)` (macOS): https://www.manpagez.com/man/1/netstat/osx-10.5.php
- `kill(2)` (macOS): https://www.manpagez.com/man/2/kill/osx-10.5.php
- `shutdown(8)` TERM/KILL sequencing pattern: https://www.manpagez.com/man/8/shutdown/osx-10.6.5.php
- Apple manual page index: https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/index.html
- Apple DTS forum thread on process/port correlation context: https://developer.apple.com/forums/thread/728731

## Unresolved Questions
- Should v1 include UDP listeners or strictly TCP LISTEN?
- Should hidden/system-owned bound ports be visible or filtered from UI list by default?
