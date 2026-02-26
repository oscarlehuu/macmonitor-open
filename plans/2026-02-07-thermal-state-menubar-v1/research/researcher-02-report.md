# Researcher 02 Report: Open-source macOS Update/Install Strategy

Date: 2026-02-07
Scope: update pipeline for non-App-Store distribution.

## Findings
- Sparkle is the strongest in-app updater path for non-App-Store macOS apps.
- Sparkle supports signed update artifacts, appcast workflow, and delta updates.
- Manual install script still needed for bootstrap/recovery/offline ops.

## Security implications
- Use Developer ID signing + notarization for all release artifacts.
- Verify signatures before install.
- Keep a rollback path (backup previous app bundle before replacement).

## Recommendation
- v1: implement manual install/update script first.
- v1.1: integrate Sparkle once app skeleton stabilizes.
- Keep script even after Sparkle for break-glass operations.

## Risks
- Manual-only updater increases operational burden and risk of human error.
- Unsigned artifacts will trigger Gatekeeper friction and trust issues.

## Sources
- https://sparkle-project.org/documentation/
- https://sparkle-project.org/documentation/publishing/
- https://developer.apple.com/support/developer-id/
- https://developer.apple.com/developer-id/
