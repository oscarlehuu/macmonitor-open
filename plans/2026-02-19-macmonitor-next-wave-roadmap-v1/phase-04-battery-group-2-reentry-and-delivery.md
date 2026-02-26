# Context links
- Parent plan: `./plan.md`
- Dependency docs: `./plans/2026-02-08-battery-management-apple-silicon-v1/phase-06-deferred-group-2-features.md`
- Inputs: `./research/researcher-02-report.md`

# Overview
- Date: 2026-02-19
- Description: reopen deferred battery group-2 scope with explicit entry gates, phased rollout, and rollback controls.
- Priority: P1
- Implementation status: implemented-local (flag-gated)
- Review status: pending-verification

# Key Insights
- Group-2 features are risky but strategically valuable.
- Lifecycle hooks exist; missing piece is robust gating and observability.
- Shipping all group-2 items at once would increase support burden.

# Requirements
- Define quantitative gate to begin group-2 implementation.
- Implement in order: sleep-aware stop charging, sleep-block-until-limit, calibration workflow, hardware percentage refinement, MagSafe LED optional.
- Add explicit rollback/disable controls for each high-risk behavior.
- Add targeted lifecycle and multi-session stress tests.

# Architecture
- Keep policy priority deterministic in `BatteryPolicyEngine`.
- Add `BatteryAdvancedControlFeatureFlags` persisted in settings.
- Add `BatteryControlSafetyMonitor` to track failures and auto-disable unstable features.
- Extend lifecycle coordinator integration points for sleep-specific policy transitions.

# Related code files
- Modify: `./MacMonitor/Sources/Core/BatteryControl/BatteryPolicyEngine.swift`
- Modify: `./MacMonitor/Sources/Core/BatteryControl/BatteryPolicyCoordinator.swift`
- Modify: `./MacMonitor/Sources/Core/BatteryControl/BatteryLifecycleCoordinator.swift`
- Modify: `./MacMonitor/Sources/Features/Settings/SettingsStore.swift`
- Modify tests: `./MacMonitor/Tests/BatteryPolicyEngineTests.swift`

# Implementation Steps
1. Define go/no-go metrics and write them into roadmap docs.
2. Add advanced feature flag model and safety monitor.
3. Implement one group-2 capability at a time with tests.
4. Run lifecycle matrix across sleep/wake/reboot/user session transitions.
5. Gate release on matrix pass and failure-rate threshold.

# Todo list
- [ ] Lock gate metrics with owner sign-off.
- [ ] Add observability fields to battery event stream.
- [ ] Add kill-switch UX copy in settings.
- [ ] Validate behavior across at least 3 Apple Silicon generations.

# Success Criteria
- Group-2 features can be enabled/disabled without data corruption.
- Failures are observable and bounded.
- Release gate metrics are documented and passed before ship.

# Risk Assessment
- Risk: unexpected power-management side effects under sleep transitions.
- Mitigation: phased enablement and automatic safety fallback.

# Security Considerations
- Preserve privileged helper command validation and bounds checks.
- Prevent unsupported command combinations from reaching helper.

# Next steps
- Execute only after phase-06 diagnostics/hardening baseline is available.
