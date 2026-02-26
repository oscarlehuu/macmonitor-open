# Contributing to MacMonitor

Thanks for helping improve MacMonitor.

## Development setup
- Install Xcode 16+ on macOS.
- Generate project files:
  - `xcodegen generate`
- Run tests locally before opening a PR:
  - `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test`

## Pull request guidelines
- Keep PRs focused and small when possible.
- Add or update tests for behavior changes.
- Update docs when user-facing behavior changes.
- Do not commit secrets, signing material, or private keys.
- Use Conventional Commit prefixes in commit messages when possible (`feat:`, `fix:`, `docs:`, `test:`, `chore:`).

## Reporting bugs and features
- Use GitHub Issues with the provided templates.
- For security reports, follow `SECURITY.md` and avoid public disclosure first.

## Code of Conduct
By participating in this project, you agree to follow `CODE_OF_CONDUCT.md`.
