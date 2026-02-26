# Solution Synthesis: Apple Silicon Battery Management (All-Free)
Date: 2026-02-08

## Objective
Create one all-free battery management system in MacMonitor, with Group 1 now and Group 2 deferred.

## Chosen approach
- Use phased architecture and keep complexity staged:
  1. Battery telemetry domain and collector.
  2. Privileged helper with secure XPC contract.
  3. Group 1 control state machine.
  4. UX + schedule + shortcuts + live status.
  5. Lifecycle hardening and rollout guardrails.
  6. Group 2 deferred with explicit re-entry gates.

## Why this wins
- Matches locked product decisions exactly.
- Preserves momentum: high-value features delivered first.
- Limits support burden by deferring unstable edge features.
- Keeps code maintainable by isolating privileged logic in helper.

## Guardrails
- No Free/Pro logic introduced in codebase.
- No Group 2 implementation in current release branch.
- Every control action must pass through same policy engine path.

## Key risks + mitigation
- Privileged architecture complexity
  - Mitigation: minimal command surface, typed protocol, tests.
- Lifecycle inconsistencies
  - Mitigation: reconciliation manager + event logging + matrix testing.
- Scope creep
  - Mitigation: explicit deferred phase and frozen Group 1 boundaries.

## Definition of done for this plan
- Group 1 features delivered and stable.
- Known lifecycle limitations documented in-app and in release notes.
- Group 2 remains deferred with measurable re-entry criteria.

## Unresolved questions
- Final choice of helper deployment flow in installer pipeline.
