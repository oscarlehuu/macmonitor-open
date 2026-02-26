# Phase 04: Policy Management UX in App Settings

## Context links
- Parent plan: `./plan.md`
- Dependencies: `./phase-01-policy-domain-and-persistence-foundation.md`, `./phase-03-notify-only-enforcement-and-event-retention.md`
- Docs: `./scout/scout-01-report.md`

## Overview
- Date: 2026-02-07
- Description: add simple UI to create/edit/enable per-app RAM policies.
- Priority: P1
- Implementation status: pending
- Review status: pending

## Key Insights
- Settings screen already exists and is the simplest reliable home for policy configuration.
- UX should stay minimal: app, threshold mode/value, trigger mode, enabled toggle.

## Requirements
- Show policy list with app name, mode, threshold, and enabled state.
- Provide add/edit flow with `%` or `GB` input.
- Provide trigger selection: immediate, sustained, or both.
- Expose sustained duration field when sustained path is used.
- Surface recent alert events summary (last trigger time/count).

## Architecture
- Add `Features/RAMPolicy/RAMPolicySettingsViewModel.swift`.
- Add `Features/RAMPolicy/RAMPolicySettingsView.swift`.
- Extend `SettingsView` with RAM policy section and navigation entry.
- Inject RAM policy services from `AppContainer`.

## Related code files
- `MacMonitor/Sources/Features/Settings/SettingsView.swift`
- `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- `MacMonitor/Sources/Core/DI/AppContainer.swift`

## Implementation Steps
1. Create view model for policy CRUD and form state.
2. Build list and editor views with inline validation.
3. Connect UI actions to policy store and monitor refresh.
4. Add small activity row for recent alerts from event store.

## Todo list
- [ ] Implement policy list UI with enable/disable toggle.
- [ ] Implement editor form for `%`/`GB` and trigger modes.
- [ ] Add validation/error messages for invalid thresholds.
- [ ] Add event summary snippet in settings.

## Success Criteria
- User can create a Cursor 10% policy in under 20 seconds.
- Policy edits persist immediately and survive relaunch.
- UI blocks invalid or ambiguous policy inputs.

## Risk Assessment
- Too many controls can overwhelm users if not sequenced clearly.
- Running-app picker may not include some helper-only targets.

## Security Considerations
- Prevent accidental policy deletion via confirmation.
- Avoid exposing sensitive process metadata in settings UI.

## Next steps
- Harden with focused tests and release guardrails.
