# Researcher 01 Report: Platform Capability + Control Constraints
Date: 2026-02-08

## Goal
Validate what macOS gives us for battery telemetry vs control, and what architecture that implies.

## Findings
- Public IOKit power-source APIs support rich read access and change notifications.
- Telemetry keys include capacity, charging state, source type, time estimates, voltage/current, temperature, cycle count, and health-condition strings.
- Existing macOS headers strongly support read/observe paths but do not expose a straightforward public high-level API for hard charge-limit control.
- Practical implementations in open-source ecosystem use privileged paths and helper/daemon patterns.
- Some older approaches have severe modern OS constraints (example: macOS 15 entitlement enforcement warnings in `bclm` project).

## Implications
- Read-only telemetry can be first-class and low-risk.
- Group 1 control requires privileged helper architecture with strict XPC boundary.
- Lifecycle reconciliation is mandatory (sleep/wake/reboot/user-switch) for user trust.

## Risks
- Platform behavior differs by OS patch and model.
- Reboot/cold boot windows cannot be fully controlled by app runtime.
- Weak helper security design creates significant risk.

## Recommendation
- Implement in phases: telemetry first, then helper, then control state machine, then automation UX, then lifecycle hardening.
- Keep Group 2 deferred until Group 1 stability targets are met.

## Sources
- `https://apphousekitchen.com/aldente-overview/features/`
- `https://apphousekitchen.com/aldente-overview/pricing/`
- `https://raw.githubusercontent.com/zackelia/bclm/master/README.md`
- `https://raw.githubusercontent.com/actuallymentor/battery/main/README.md`
- `https://raw.githubusercontent.com/mhaeuser/Battery-Toolkit/main/README.md`
- macOS SDK headers inspected locally:
  - `IOPowerSources.h`
  - `IOPSKeys.h`
  - `IOPM.h`
  - `IOPMLib.h`

## Unresolved questions
- Exact helper install/update mechanism to use in this repo (SMJobBless vs alternative packaging flow).
