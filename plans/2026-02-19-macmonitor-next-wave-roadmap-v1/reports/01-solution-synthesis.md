# 01 Solution Synthesis - MacMonitor Next-Wave Roadmap

## Inputs
- `./plans/2026-02-19-macmonitor-next-wave-roadmap-v1/research/researcher-01-report.md`
- `./plans/2026-02-19-macmonitor-next-wave-roadmap-v1/research/researcher-02-report.md`
- `./plans/2026-02-19-macmonitor-next-wave-roadmap-v1/scout/scout-01-report.md`

## Decision
Use a 6-phase roadmap that maximizes reuse of existing infrastructure before adding risky battery controls.

## Why this sequence
1. Ship user-visible value quickly by exposing already-built battery scheduling internals.
2. Convert existing snapshot persistence into trends and actionable alerts.
3. Expand telemetry scope via collector architecture with low coupling.
4. Re-open deferred battery group-2 only after diagnostics and gating are in place.
5. Add widget/automation read surfaces after snapshot contract hardens.
6. Harden release/support with diagnostics export and targeted lifecycle tests.

## Trade-offs considered
- One giant release: rejected. Too much regression risk in helper + lifecycle + telemetry changes.
- Group-2 battery first: rejected. Higher support burden than schedule/trends.
- GPU-first telemetry: rejected for now. CPU/network are lower risk and easier to validate.

## Release mapping
- Release A (v1.4): Phase 01 + Phase 02.
- Release B (v1.5): Phase 03 + Phase 05.
- Release C (v1.6): Phase 06 + Phase 04 (only if entry gates pass).

## Architecture constraints to preserve
- Keep battery policy priority deterministic and test-backed.
- Preserve protected-action posture used by RAM/storage termination flows.
- Avoid schema churn before widget contract is versioned.

## Unresolved questions
- Confirm desired trends retention window (`24h`, `7d`, `30d`).
- Confirm whether GPU metrics are mandatory in v1.5.
- Confirm whether recurring battery schedules are required in first schedule UI release.
