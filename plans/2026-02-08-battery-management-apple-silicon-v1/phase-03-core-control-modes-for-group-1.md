# Context links
- Parent plan: `./plan.md`
- Dependency phase: `./phase-02-privileged-helper-and-xpc-control-backend.md`
- Reports: `./reports/01-solution-synthesis.md`

# Overview
- Date: 2026-02-08
- Description: Implement Group 1 core battery control features and runtime policy engine.
- Priority: P1
- Implementation status: in_progress (85%)
- Review status: pending

# Key Insights
- Most Group 1 value is in control-policy behavior, not just command buttons.
- A single state machine reduces conflicts between top-up, discharge, sailing, and heat protection.

# Requirements
- Implement: charge limiter, manual discharge, automatic discharge.
- Implement: top up, sailing mode, heat protection.
- Implement: stop charging when app closed behavior via helper-held policy.
- Implement: fast user switching continuity.
- Implement: power flow state model (`charging`, `paused`, `discharging`, `topUp`, `heatProtect`, `sailing`).
- Enforce user charge-limit inputs to `50%-95%` in Group 1.
<!-- Updated: Validation Session 1 - lock charge-limit safety bounds to 50-95 -->

# Architecture
- Battery policy engine in app computes desired control state.
- Helper enforces desired state and reports effective state.
- Conflict precedence (highest first): safety/heat > top up > manual discharge > automatic discharge > sailing > steady limit.

# Related code files
- Create: `MacMonitor/Sources/Core/BatteryControl/BatteryPolicyEngine.swift`
- Create: `MacMonitor/Sources/Core/BatteryControl/BatteryControlState.swift`
- Modify: `MacMonitor/Sources/Features/Settings/SettingsStore.swift`
- Modify: `MacMonitor/Sources/Core/DI/AppContainer.swift`
- Create tests: `MacMonitor/Tests/BatteryPolicyEngineTests.swift`
- Create tests: `MacMonitor/Tests/BatteryControlStateMachineTests.swift`

# Implementation Steps
1. Define policy config schema for Group 1 settings, including `50%-95%` input bounds.
2. Implement deterministic state machine with precedence rules.
3. Map state transitions to backend commands.
4. Persist policies and restore on launch/login/user switch.
5. Add regression tests for conflicting mode combinations.
<!-- Updated: Validation Session 1 - bounds enforcement added to policy schema -->

# Todo list
- [x] Finalize policy schema.
- [x] Implement state machine + transitions.
- [x] Wire commands to helper backend.
- [x] Persist and hydrate policies.
- [x] Add scenario tests for mode conflicts.

# Success Criteria
- Group 1 modes work individually and in combination.
- State transitions are deterministic and test-covered.
- Policy survives app restart and user switching.

# Risk Assessment
- Race conditions between telemetry refresh and command acknowledgement.
- Edge-case instability when battery jumps rapidly around thresholds.

# Security Considerations
- Validate policy values with hard range checks (`50%-95%`) for charge-limit inputs.
- Block invalid command issuance from corrupted state.
<!-- Updated: Validation Session 1 - explicit threshold range in security controls -->

# Next steps
- Expose controls and automations in UX in Phase 04.
