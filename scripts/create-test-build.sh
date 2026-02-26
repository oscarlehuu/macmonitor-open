#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/MacMonitor.xcodeproj"
SCHEME="MacMonitor"
DESTINATION="platform=macOS"
DERIVED_DATA_PATH="$ROOT_DIR/build/share"
ARTIFACTS_DIR="$ROOT_DIR/dist"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/MacMonitor.app"
ZIP_PATH="$ARTIFACTS_DIR/MacMonitor-test.zip"

mkdir -p "$ARTIFACTS_DIR"
rm -rf "$DERIVED_DATA_PATH"
rm -f "$ZIP_PATH"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  clean build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=""

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded but app was not found at: $APP_PATH" >&2
  exit 1
fi

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
rm -rf "$DERIVED_DATA_PATH"
echo "Created test build zip: $ZIP_PATH"
