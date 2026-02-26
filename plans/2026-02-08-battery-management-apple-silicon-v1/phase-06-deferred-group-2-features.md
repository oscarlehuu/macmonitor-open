# Context links
- Parent plan: `./plan.md`
- Dependency phase: `./phase-05-hardening-for-sleep-wake-reboot-user-switch.md`
- Reports: `./reports/01-solution-synthesis.md`

# Overview
- Date: 2026-02-08
- Description: Park Group 2 features with clear criteria; do not implement in current delivery.
- Priority: P2
- Implementation status: deferred
- Review status: pending

# Key Insights
- Group 2 is valuable but carries higher lifecycle unpredictability and support burden.
- Deferral reduces risk and preserves momentum for Group 1 release quality.

# Requirements
- Defer implementation of:
  - Stop charging when sleeping.
  - Disable sleep until charge limit.
  - Calibration mode automation.
  - Hardware battery percentage refinement.
  - Optional MagSafe LED control.
- Define precise re-entry criteria for each deferred feature.
- Define proof-of-stability threshold from Group 1 before reopening scope.

# Architecture
- Keep extension points in policy engine and scheduler.
- Avoid partial feature flags for Group 2 in v1.3.
- Store deferred requirements as backlog spec, not runtime switches.

# Related code files
- No implementation files in this phase by design.
- Docs-only updates in plan directory.

# Implementation Steps
1. Document deferred items and rationales.
2. Define measurable re-entry gates.
3. Add backlog notes for required technical spikes.

# Todo list
- [ ] Record each deferred feature with risk and dependency.
- [ ] Define re-entry quality gates.
- [ ] Keep v1.3 release scope frozen to Group 1.

# Success Criteria
- Team has explicit, stable boundary between now vs later.
- No Group 2 work leaks into current implementation branch.

# Risk Assessment
- Feature pressure may cause scope creep if boundaries not enforced.

# Security Considerations
- None beyond standard project controls; this phase is docs-only.

# Next steps
- Revisit after Group 1 production-quality stabilization.
