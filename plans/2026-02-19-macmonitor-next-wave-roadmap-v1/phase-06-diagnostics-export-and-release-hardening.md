# Context links
- Parent plan: `./plan.md`
- Inputs: `./research/researcher-02-report.md`
- Core files: `./MacMonitor/Sources/Core/BatteryControl/BatteryEventStore.swift`, `./.github/workflows/ci.yml`

# Overview
- Date: 2026-02-19
- Description: add one-click diagnostics export and strengthen release confidence for helper/lifecycle features.
- Priority: P1
- Implementation status: implemented-local
- Review status: pending-verification

# Key Insights
- Battery event logs already capture structured outcomes and command context.
- Support burden grows with helper and lifecycle complexity.
- CI currently checks build/test but not deep lifecycle stress paths.

# Requirements
- Add diagnostics export bundle containing sanitized settings, recent events, lifecycle traces, version/build info, and helper status.
- Add UI action to generate and reveal diagnostics bundle.
- Add release hardening checklist and targeted lifecycle regression suite.
- Ensure diagnostics omit user-sensitive file paths where unnecessary.

# Architecture
- Add `DiagnosticsExporter` service with redaction rules.
- Reuse existing event stores for payload generation.
- Add deterministic test harness for lifecycle simulations.

# Related code files
- Create: `./MacMonitor/Sources/Core/Diagnostics/DiagnosticsExporter.swift`
- Modify: `./MacMonitor/Sources/Features/Settings/SettingsView.swift`
- Modify: `./MacMonitor/Sources/Core/BatteryControl/BatteryEventStore.swift`
- Modify CI: `./.github/workflows/ci.yml`

# Implementation Steps
1. Define diagnostics bundle schema and redaction policy.
2. Implement exporter and file packaging flow.
3. Add settings UI button and success/error states.
4. Add tests for payload completeness and redaction.
5. Add lifecycle-focused CI job(s) and release checklist update.

# Todo list
- [ ] Finalize diagnostics schema and retention.
- [ ] Add explicit PII redaction tests.
- [ ] Add helper install/availability checks in diagnostics output.
- [ ] Update README/support docs for bug report workflow.

# Success Criteria
- User can generate diagnostics in under 10 seconds.
- Export includes enough detail to reproduce common failures.
- No sensitive data leaks in exported artifacts.

# Risk Assessment
- Risk: diagnostics contain overly broad local data.
- Mitigation: strict allowlist of fields and redaction tests.

# Security Considerations
- Sanitize paths, usernames, and arbitrary command output.
- Keep diagnostics local unless user explicitly shares file.

# Next steps
- Use diagnostics baseline before enabling battery group-2 rollout.
