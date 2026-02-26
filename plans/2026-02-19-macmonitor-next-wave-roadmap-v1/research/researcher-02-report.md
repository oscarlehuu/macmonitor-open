# Researcher 02 Report - Risk, Safety, and Platform Constraints

## Objective
Identify delivery risks and guardrails for the next feature wave.

## Sources
- `./plans/2026-02-08-battery-management-apple-silicon-v1/phase-06-deferred-group-2-features.md:18`
- `./MacMonitor/Sources/Core/BatteryControl/BatteryLifecycleCoordinator.swift:5`
- `./MacMonitor/Sources/Core/BatteryControl/BatteryPolicyEngine.swift:5`
- `./MacMonitor/Sources/Core/BatteryControl/BatteryEventStore.swift:1`
- `./MacMonitor/Sources/Core/Storage/StorageProtectionPolicy.swift:1`
- `./MacMonitor/Sources/Core/Storage/RunningAppPreflightCoordinator.swift:1`
- `./.github/workflows/ci.yml:1`

## Findings
1. Battery group-2 features are explicitly deferred, with lifecycle unpredictability called out.
- Scope creep risk is known and documented.
- Re-entry should be gated by measurable stability signals, not urgency.

2. Lifecycle events already exist for sleep/wake and session active/resign.
- Good foundation for sleep-aware charging behaviors.
- Need stricter state reconciliation and failure telemetry before enabling aggressive policies.

3. Policy precedence is already strict and safety-first.
- Heat protection and bounds are codified.
- New controls must preserve deterministic priority ordering to avoid oscillation.

4. Event persistence exists for auditability.
- Battery events store source/state/command/accepted/message.
- This enables diagnostics export with minimal new plumbing.

5. Project already favors safe destructive actions.
- Storage deletion has explicit protection policy and preflight termination paths.
- Same safety posture should be applied to future battery force behaviors.

6. CI currently validates build + tests only.
- No dedicated matrix for battery helper/install/lifecycle stress.
- Roadmap should include deterministic lifecycle regression tests before high-risk battery features.

## Risk ranking
- High: sleep-interference features (`disable sleep until limit`, calibration automation).
- Medium: new telemetry collectors that may increase refresh overhead.
- Medium: widget/app-group schema drift once externalized.
- Low-medium: schedule UX if built as one-shot first and bounded.

## Guardrails
- Keep battery policy with explicit priority table and test matrix.
- Add feature-level kill switches for high-risk battery behaviors.
- Add diagnostics bundle before shipping group-2 controls.
- Keep first telemetry expansion to CPU+network; defer GPU if signal quality is poor.

## Unresolved questions
- Acceptable battery policy failure budget before enabling group-2 features.
- Whether to ship calibration mode only as explicit manual workflow first.
- Whether update cadence should remain minute-level after adding collectors.
