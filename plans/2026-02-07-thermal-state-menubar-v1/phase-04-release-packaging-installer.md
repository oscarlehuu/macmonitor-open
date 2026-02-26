# Phase 04: Release Packaging + Installer Script

## Context links
- Parent plan: `./plan.md`
- Dependencies: Phases 01-03
- Docs: Developer ID signing, notarization, Sparkle docs (future)

## Overview
- Date: 2026-02-07
- Description: define reproducible release artifact pipeline and installer/update script for v1.
- Priority: P1
- Implementation status: pending
- Review status: pending

## Key Insights
- Manual script is enough for v1 if verification and backup are mandatory.
- Keep script idempotent to reduce operator mistakes.

## Requirements
- Build notarized release artifact (`.zip` or `.dmg`) containing `.app`.
- Installer script supports URL or local artifact input.
- Script verifies checksums/signatures and performs safe replacement with backup.
- Release checklist and rollback procedure documented.

## Architecture
- `scripts/install-macmonitor-update.sh`: installer/updater entrypoint.
- `scripts/release-checklist.md`: build, sign, notarize, publish steps.
- `scripts/install-example.env`: reusable invocation config.

## Related code files
- `scripts/install-macmonitor-update.sh`
- `scripts/release-checklist.md`
- `.github/workflows/release.yml` (future)

## Implementation Steps
1. Define artifact contract (app name, archive format, checksum file).
2. Implement install script with strict shell safety.
3. Add signature/assessment checks and rollback backup.
4. Add release checklist doc and dry-run test matrix.
5. Validate script on fresh machine + upgrade scenario.

## Todo list
- [ ] URL download + local path handling.
- [ ] ZIP/DMG extraction + mount/unmount safety.
- [ ] Atomic swap strategy (`ditto` + backup folder).
- [ ] Error codes mapped to clear diagnostics.

## Success Criteria
- Upgrade from previous app version succeeds without manual file surgery.
- Backup app remains restorable when install fails.
- Script works non-interactively for CI/operator usage.

## Risk Assessment
- DMG mount failures and stale mount points can break automation.
- Signature checks may fail on unsigned debug artifacts (need explicit bypass mode for dev only).

## Security Considerations
- Default to enforcing checksum and code-sign verification for release paths.
- Avoid auto-running post-install binaries from untrusted temp locations.

## Next steps
- Optionally integrate Sparkle once base app and release rhythm stabilize.
