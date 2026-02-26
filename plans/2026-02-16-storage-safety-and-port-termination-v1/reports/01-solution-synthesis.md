# Solution Synthesis
Date: 2026-02-16

## Problem
Two behaviors need coordinated design:
1. Deleting a selected app bundle while it is still running.
2. Terminating development servers/services by selected ports.

## Chosen v1 Approach
- Use a two-stage destructive flow in both feature tracks:
1. Graceful termination first.
2. Explicit force fallback only for survivors after graceful timeout.
- Keep force fallback as a second dialog, never default.
- Reuse process protection rules and existing termination result semantics.
- Limit Ports mode to TCP `LISTEN` for v1.

## Why this approach
- Matches safety requirements while still unblocking stuck processes/apps.
- Minimizes scope by reusing current architecture (`ProcessProtectionPolicy`, `SignalProcessTerminator`, existing view-model orchestration patterns).
- Keeps implementation incremental and testable via phase boundaries.

## Design Constraints
- Existing uncommitted storage file/test changes must be preserved.
- No code implementation in this planning step.

## References
- `./plans/2026-02-16-storage-safety-and-port-termination-v1/research/researcher-01-report.md`
- `./plans/2026-02-16-storage-safety-and-port-termination-v1/research/researcher-02-report.md`
- `./plans/2026-02-16-storage-safety-and-port-termination-v1/scout/scout-01-report.md`

## Unresolved Questions
- Force fallback batch behavior: one dialog for all survivors or per-app/per-port group.
- Visibility policy for blocked/system-owned ports in UI.
