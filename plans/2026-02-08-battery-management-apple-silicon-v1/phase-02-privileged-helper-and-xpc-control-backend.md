# Context links
- Parent plan: `./plan.md`
- Dependency phase: `./phase-01-battery-domain-and-readonly-telemetry-pipeline.md`
- Reports: `./research/researcher-01-report.md`, `./reports/01-solution-synthesis.md`

# Overview
- Date: 2026-02-08
- Description: Establish privileged helper, secure XPC protocol, and backend abstraction for battery control.
- Priority: P1
- Implementation status: in_progress
- Review status: pending

# Key Insights
- Group 1 control features require privileged operations and must survive app restarts.
- Main app should not contain low-level control logic directly.
- Helper contract must be minimal, authenticated, and testable.

# Requirements
- Define `BatteryControlBackend` protocol with commands needed by Group 1.
- Implement helper service for privileged battery actions.
- Use `SMJobBless` as the privileged helper installation and update mechanism.
- Add XPC request/response contract with versioning.
- Add fallback behavior when helper unavailable.
- Add diagnostics channel for command result and last error.
<!-- Updated: Validation Session 1 - lock helper install model to SMJobBless -->

# Architecture
- App process: UI + policy engine + scheduler.
- Helper process: executes privileged commands only; provisioned via `SMJobBless`.
- XPC boundary: typed command envelope, explicit result codes.
- State cache: app stores desired policy; helper enforces actual platform state.
<!-- Updated: Validation Session 1 - helper architecture hard-locked to SMJobBless -->

# Related code files
- Create: `MacMonitor/Sources/Core/BatteryControl/BatteryControlBackend.swift`
- Create: `MacMonitor/Sources/Core/BatteryControl/BatteryControlService.swift`
- Create: `MacMonitor/Sources/Core/BatteryControl/XPC/*`
- Modify: `project.yml` (helper target, entitlements, signing settings)
- Modify: `MacMonitor/Sources/Core/DI/AppContainer.swift`
- Create tests: `MacMonitor/Tests/BatteryControlBackendTests.swift`

# Implementation Steps
1. Define backend interface and command taxonomy.
2. Add helper target, `SMJobBless` integration, and XPC plumbing in project config.
3. Implement request validation and authenticated caller checks.
4. Implement backend state query APIs for observability.
5. Add integration tests for happy-path and denied-path flows.
<!-- Updated: Validation Session 1 - require SMJobBless wiring -->

# Todo list
- [x] Finalize backend command set.
- [ ] Add helper target and XPC service.
- [x] Implement result/error mapping.
- [x] Add resiliency around helper restart.
- [ ] Add automated tests for protocol compatibility.

# Success Criteria
- App can issue signed/authenticated command via XPC.
- Helper returns deterministic result and state.
- Failure mode is visible in app without crashes.

# Risk Assessment
- Codesign and helper installation friction can delay delivery.
- macOS privilege model changes may require backend adaptation.

# Security Considerations
- Restrict helper API to minimum commands.
- Validate caller identity and signature before action.
- Avoid shell injection by using strict argument encoding.

# Next steps
- Build Group 1 control semantics in Phase 03.
