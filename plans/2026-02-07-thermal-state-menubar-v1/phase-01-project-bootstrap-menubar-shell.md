# Phase 01: Project Bootstrap + Menu Bar Shell

## Context links
- Parent plan: `./plan.md`
- Dependencies: none
- Docs: Apple SwiftUI/AppKit menu bar integration docs

## Overview
- Date: 2026-02-07
- Description: initialize Xcode project skeleton and status item host.
- Priority: P1
- Implementation status: pending
- Review status: pending

## Key Insights
- App should be menu bar-first (`NSStatusItem`), not dock-first.
- Keep model/services framework-independent so widget can consume later.

## Requirements
- Create macOS app target for Apple Silicon.
- Create status bar icon + popover shell.
- Add run-loop-safe refresh scheduler foundation.

## Architecture
- `App/`: app lifecycle and DI root.
- `Features/MenuBar/`: status item controller + popover wiring.
- `Core/`: shared model/service contracts.

## Related code files
- `MacMonitor/App/MacMonitorApp.swift`
- `MacMonitor/Features/MenuBar/MenuBarController.swift`
- `MacMonitor/Features/MenuBar/PopoverRootView.swift`
- `MacMonitor/Core/DI/AppContainer.swift`

## Implementation Steps
1. Create Xcode project with SwiftUI app entrypoint.
2. Add AppKit bridge for menu bar status item.
3. Build popover shell with placeholder cards.
4. Add central timer service with injectable clock.
5. Add logging categories for diagnostics.

## Todo list
- [ ] Initialize project + folder structure.
- [ ] Add status item icon state variants.
- [ ] Add popover show/hide handling.
- [ ] Add unit test target and smoke test.

## Success Criteria
- App runs as menu bar item with stable popover behavior.
- No crashes on rapid open/close interactions.

## Risk Assessment
- Popover lifecycle bugs can leak controllers.
- Timer ownership bugs can create duplicate refresh loops.

## Security Considerations
- No privileged APIs in this phase.
- Ensure no shell command execution in UI layer.

## Next steps
- Move to Phase 02 metrics collectors and domain modeling.
