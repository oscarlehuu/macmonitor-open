# Researcher 01 Report: macOS Process Memory + Termination Constraints

## Goal
Identify reliable APIs for process memory ranking and safe termination from a user-level menu bar app on macOS 14+.

## Findings
- `libproc` exposes `proc_listpids` and `proc_pidinfo`, and `sys/proc_info.h` defines `PROC_PIDTASKALLINFO` with `proc_taskinfo.pti_resident_size`.
- `libproc` also exposes `proc_pid_rusage`, and `sys/resource.h` defines `RUSAGE_INFO_CURRENT` plus `ri_phys_footprint` and `ri_resident_size` fields.
- `kill(2)` explicitly limits signaling by permission: non-privileged callers can signal processes with matching real/effective UID; otherwise `EPERM`.
- `NSWorkspace.runningApplications` / `NSRunningApplication` cover user applications only (not all system processes), but provide `terminate`/`forceTerminate` conveniences.
- `libproc.h` marks these interfaces as private and subject to change, so we need defensive coding + fallback behavior.

## Recommended API Strategy
1. Enumerate PIDs with `proc_listpids(PROC_ALL_PIDS, ...)`.
2. For each PID, gather:
- `proc_pidinfo(..., PROC_PIDTASKALLINFO, ...)` for process identity + resident size.
- Optional `proc_pid_rusage(..., RUSAGE_INFO_CURRENT, ...)` for footprint metric.
3. Build an in-app `ProcessMemoryItem` list and rank by chosen metric.
4. Termination flow:
- Validate policy first (protected/system/self/ownership checks).
- Send `SIGTERM` via `kill(pid, SIGTERM)`.
- Record per-PID result (`success`, `permissionDenied`, `notFound`, `protected`, `failed`).
- Keep `SIGKILL` optional and off by default for MVP.

## Practical Constraints
- PIDs can exit between enumerate and inspect; collectors must treat `ESRCH` as non-fatal.
- `NSWorkspace` list is incomplete for true “top memory” use case; use it only as fallback metadata source.
- Private API stability risk from `libproc` needs version-tolerant wrappers and strict result-size checks.

## Sources
- `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/libproc.h`
- `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/sys/proc_info.h`
- `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/sys/resource.h`
- `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/AppKit.framework/Headers/NSRunningApplication.h`
- `man 2 kill`

## Unresolved Questions
- Should default ranking use `ri_phys_footprint` or `pti_resident_size` in UI?
- Do we allow optional force-kill (`SIGKILL`) in v1 or defer to v1.1?
