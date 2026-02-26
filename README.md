# MacMonitor

Open-source macOS (Apple Silicon) menu bar monitor.

## Current scope (v1)
- Thermal state via official API (`nominal/fair/serious/critical`)
- RAM usage / total
- RAM details view with top processes, multi-select, and allowed-only termination
- Storage usage / total
- Refresh every few minutes (configurable)

## Build
1. Generate project:
   - `xcodegen generate`
2. Build and test:
   - `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test`

## Versioning and releases
- Versioning uses SemVer (`MAJOR.MINOR.PATCH`) via `release-please`.
- Merge PRs to `main` using Conventional Commits:
  - `feat:` => minor
  - `fix:` / `deps:` => patch
  - `feat!:` or `BREAKING CHANGE:` => major
- Docs/chore/test-only merges do not create a release.
- Sparkle update assets + appcast are published automatically when a GitHub Release is published.
- Required CI secrets are documented in `scripts/release-checklist.md` (`RELEASE_PLEASE_TOKEN`, `SPARKLE_PRIVATE_KEY`, `UPDATES_REPO_TOKEN`, `APPLE_CERTIFICATE_P12_BASE64`, `APPLE_CERTIFICATE_PASSWORD`, `APPLE_SIGNING_IDENTITY`, `APPLE_NOTARY_KEY_ID`, `APPLE_NOTARY_ISSUER_ID`, `APPLE_NOTARY_API_KEY_BASE64`).
- See `scripts/release-checklist.md` for full release flow and secrets.
- For forks, configure repository variable `UPDATES_REPO` (format: `owner/repo`) if your update feed repository is not `<owner>/macmonitor-updates`.

## Install new build
Use:
- `./scripts/install-macmonitor-update.sh`

## Community
- Contributing guide: `CONTRIBUTING.md`
- Code of conduct: `CODE_OF_CONDUCT.md`
- Security policy: `SECURITY.md`
