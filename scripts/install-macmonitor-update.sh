#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MacMonitor.app"
DEST_DIR="/Applications"
SOURCE=""
EXPECTED_SHA256=""
RELAUNCH=false
SKIP_SIGNATURE_CHECK=false
SKIP_GATEKEEPER_CHECK=false
KEEP_QUARANTINE=false

MOUNT_POINT=""
TMP_DIR=""
ARTIFACT_PATH=""
EXTRACTED_APP_PATH=""

usage() {
  cat <<USAGE
Usage:
  $(basename "$0") --source <path-or-url> [options]

Required:
  --source <path-or-url>        Local artifact path or HTTPS URL.

Options:
  --app-name <name.app>         App bundle name. Default: ${APP_NAME}
  --dest-dir <path>             Install directory. Default: ${DEST_DIR}
  --sha256 <hex>                Expected SHA-256 for downloaded/local artifact.
  --relaunch                    Relaunch app after successful install.
  --skip-signature-check        Skip codesign verification (debug builds only).
  --skip-gatekeeper-check       Skip spctl assessment.
  --keep-quarantine             Keep quarantine xattr on installed app.
  -h, --help                    Show help.

Examples:
  $(basename "$0") --source ./MacMonitor.zip --sha256 <hash>
  $(basename "$0") --source https://example.com/MacMonitor.zip --relaunch
USAGE
}

log() { printf '[INFO] %s\n' "$*" >&2; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

cleanup() {
  set +e
  if [[ -n "${MOUNT_POINT}" ]]; then
    hdiutil detach "${MOUNT_POINT}" -quiet >/dev/null 2>&1
  fi
  if [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]]; then
    rm -rf "${TMP_DIR}"
  fi
}
trap cleanup EXIT

is_url() {
  [[ "$1" =~ ^https?:// ]]
}

sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source)
        SOURCE="${2:-}"; shift 2 ;;
      --app-name)
        APP_NAME="${2:-}"; shift 2 ;;
      --dest-dir)
        DEST_DIR="${2:-}"; shift 2 ;;
      --sha256)
        EXPECTED_SHA256="${2:-}"; shift 2 ;;
      --relaunch)
        RELAUNCH=true; shift ;;
      --skip-signature-check)
        SKIP_SIGNATURE_CHECK=true; shift ;;
      --skip-gatekeeper-check)
        SKIP_GATEKEEPER_CHECK=true; shift ;;
      --keep-quarantine)
        KEEP_QUARANTINE=true; shift ;;
      -h|--help)
        usage; exit 0 ;;
      *)
        fail "Unknown argument: $1" ;;
    esac
  done

  [[ -n "${SOURCE}" ]] || fail "--source is required"
  [[ "${APP_NAME}" == *.app ]] || fail "--app-name must end with .app"
}

prepare_source() {
  TMP_DIR="$(mktemp -d)"
  local artifact_path=""

  if is_url "${SOURCE}"; then
    require_cmd curl
    local source_basename
    source_basename="$(basename "${SOURCE%%\?*}")"
    if [[ -z "${source_basename}" || "${source_basename}" == "/" ]]; then
      source_basename="artifact.bin"
    fi
    artifact_path="${TMP_DIR}/${source_basename}"
    log "Downloading artifact: ${SOURCE}"
    curl -fL --retry 3 --connect-timeout 15 --max-time 300 -o "${artifact_path}" "${SOURCE}"
  else
    [[ -e "${SOURCE}" ]] || fail "Source not found: ${SOURCE}"
    artifact_path="${SOURCE}"
  fi

  if [[ -n "${EXPECTED_SHA256}" ]]; then
    require_cmd shasum
    local actual
    actual="$(sha256_file "${artifact_path}")"
    [[ "${actual}" == "${EXPECTED_SHA256}" ]] || fail "SHA-256 mismatch. Expected ${EXPECTED_SHA256}, got ${actual}"
    log "SHA-256 verified"
  fi

  ARTIFACT_PATH="${artifact_path}"
}

extract_app_path() {
  local artifact="$1"
  local lower
  lower="$(printf '%s' "${artifact}" | tr '[:upper:]' '[:lower:]')"

  if [[ -d "${artifact}" && "$(basename "${artifact}")" == "${APP_NAME}" ]]; then
    EXTRACTED_APP_PATH="${artifact}"
    return
  fi

  local extract_dir="${TMP_DIR}/extract"
  mkdir -p "${extract_dir}"

  if [[ "${lower}" == *.zip ]]; then
    require_cmd ditto
    ditto -x -k "${artifact}" "${extract_dir}"
  elif [[ "${lower}" == *.dmg ]]; then
    require_cmd hdiutil
    MOUNT_POINT="${TMP_DIR}/mount"
    mkdir -p "${MOUNT_POINT}"
    hdiutil attach "${artifact}" -mountpoint "${MOUNT_POINT}" -nobrowse -readonly -quiet
    extract_dir="${MOUNT_POINT}"
  elif [[ "${lower}" == *.tar.gz || "${lower}" == *.tgz ]]; then
    require_cmd tar
    tar -xzf "${artifact}" -C "${extract_dir}"
  elif [[ "${lower}" == *.app ]]; then
    EXTRACTED_APP_PATH="${artifact}"
    return
  else
    fail "Unsupported artifact type: ${artifact}"
  fi

  local found
  found="$(find "${extract_dir}" -maxdepth 3 -type d -name "${APP_NAME}" | head -n 1 || true)"
  [[ -n "${found}" ]] || fail "Could not locate ${APP_NAME} inside artifact"
  EXTRACTED_APP_PATH="${found}"
}

verify_app() {
  local app_path="$1"

  if [[ "${SKIP_SIGNATURE_CHECK}" == false ]]; then
    require_cmd codesign
    codesign --verify --deep --strict --verbose=2 "${app_path}" || fail "codesign verification failed"
    log "Code signature verified"
  else
    warn "Skipping code signature verification"
  fi

  if [[ "${SKIP_GATEKEEPER_CHECK}" == false ]]; then
    require_cmd spctl
    spctl --assess --type execute --verbose=2 "${app_path}" || fail "Gatekeeper assessment failed"
    log "Gatekeeper assessment passed"
  else
    warn "Skipping Gatekeeper assessment"
  fi
}

install_app() {
  local app_path="$1"
  require_cmd ditto

  mkdir -p "${DEST_DIR}"
  local target_app="${DEST_DIR}/${APP_NAME}"

  if [[ -d "${target_app}" ]]; then
    local backup_path="${DEST_DIR}/${APP_NAME}.backup-$(date +%Y%m%d-%H%M%S)"
    log "Backing up existing app to ${backup_path}"
    ditto "${target_app}" "${backup_path}"
  fi

  log "Installing ${APP_NAME} to ${DEST_DIR}"
  rm -rf "${target_app}"
  ditto "${app_path}" "${target_app}"

  if [[ "${KEEP_QUARANTINE}" == false ]]; then
    require_cmd xattr
    xattr -dr com.apple.quarantine "${target_app}" >/dev/null 2>&1 || true
  fi

  log "Install complete: ${target_app}"

  if [[ "${RELAUNCH}" == true ]]; then
    local app_base
    app_base="${APP_NAME%.app}"
    pkill -x "${app_base}" >/dev/null 2>&1 || true
    open -a "${target_app}" || warn "Relaunch failed, start app manually"
  fi
}

main() {
  require_cmd find
  parse_args "$@"

  prepare_source
  extract_app_path "${ARTIFACT_PATH}"

  verify_app "${EXTRACTED_APP_PATH}"
  install_app "${EXTRACTED_APP_PATH}"

  log "Done"
}

main "$@"
