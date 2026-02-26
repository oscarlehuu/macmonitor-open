# Researcher 02 Report: App RAM Attribution, Thresholds, and Notify Flow

## Goal
Identify how to compute per-app RAM usage (main + helpers) and evaluate alert thresholds with no kill/quit action.

## Findings
- Process memory inventory already exists in `LibprocProcessListCollector` and returns rich per-PID rows.
- `RAMDetailsViewModel` already computes aggregate totals from collected rows and refreshes every 5 seconds.
- Current product already includes termination path; new policy feature must stay separate and notify-only.
- `MetricsEngine` has app-wide timer orchestration and is a reasonable host for a policy monitor coordinator.

## Recommended Attribution Rule
1. Enumerate discoverable processes.
2. Resolve each PID executable path (`proc_pidpath`) and infer owning `.app` bundle path when present.
3. Derive bundle id from bundle path.
4. Group by bundle id and sum ranking bytes across all processes in same app bundle (main + helpers).

## Recommended Threshold Rule
- `percent` mode: `thresholdBytes = physicalMemory * percent / 100`
- `absoluteGB` mode: `thresholdBytes = GB * 1024^3`
- Trigger modes:
  - `immediate`: alert on first sample above threshold
  - `sustained`: alert only when over threshold continuously for `sustainedSeconds`
  - `both`: support both paths

## Recommended Enforcement Rule
- Action is `notify` only.
- Add cooldown per policy to prevent spam.
- Keep 7-day event history and prune on append/startup.

## Risks
- Bundle attribution can be imperfect for non-bundled binaries and transient helper processes.
- Notification permission denial must degrade gracefully to in-app event logging.

## Sources
- `./MacMonitor/Sources/Core/Processes/LibprocProcessListCollector.swift`
- `./MacMonitor/Sources/Features/RAMDetails/RAMDetailsViewModel.swift`
- `./MacMonitor/Sources/Core/Metrics/MetricsEngine.swift`

## Unresolved Questions
- Should unknown/non-bundled processes be ignored or grouped under an `Unknown App` bucket for user visibility?
