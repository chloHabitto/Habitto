#!/bin/bash
# Ensures the archive Info.plist has a valid nested ApplicationProperties dict
# so Xcode Organizer groups the archive under Habitto (not "Other Items").
# Intended to run as an Archive scheme post-action via $ARCHIVE_PATH.

set -euo pipefail

LOG_FILE="${HOME}/Library/Logs/fix-archive.log"
TEAM_FALLBACK="GVG7JYM6M8"
APP_NAME="Habitto"

log() {
  local msg="$1"
  echo "$(date '+%Y-%m-%d %H:%M:%S'): ${msg}" | tee -a "$LOG_FILE"
}

plist_print() {
  /usr/libexec/PlistBuddy -c "Print $1" "$2" 2>/dev/null || true
}

plist_has_key() {
  /usr/libexec/PlistBuddy -c "Print $1" "$2" >/dev/null 2>&1
}

plist_set_or_add_string() {
  local key="$1"
  local value="$2"
  local plist="$3"
  if plist_has_key "$key" "$plist"; then
    /usr/libexec/PlistBuddy -c "Set $key '$value'" "$plist"
  else
    /usr/libexec/PlistBuddy -c "Add $key string '$value'" "$plist"
  fi
}

application_properties_valid() {
  local plist="$1"
  local required_keys=(
    ":ApplicationProperties:ApplicationPath"
    ":ApplicationProperties:CFBundleIdentifier"
    ":ApplicationProperties:CFBundleShortVersionString"
    ":ApplicationProperties:CFBundleVersion"
  )
  local key
  for key in "${required_keys[@]}"; do
    local value
    value="$(plist_print "$key" "$plist")"
    if [ -z "$value" ]; then
      return 1
    fi
  done
  return 0
}

ARCHIVE_PATH="${ARCHIVE_PATH:-${1:-}}"

log "=== fix-archive.sh started ==="
log "ARCHIVE_PATH=${ARCHIVE_PATH:-<empty>}"

if [ -z "${ARCHIVE_PATH}" ] || [ ! -d "${ARCHIVE_PATH}" ]; then
  log "ERROR: ARCHIVE_PATH is missing or not a directory"
  exit 1
fi

ARCHIVE_PLIST="${ARCHIVE_PATH}/Info.plist"
APP_PATH="${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app"
APP_PLIST="${APP_PATH}/Info.plist"

if [ ! -f "${ARCHIVE_PLIST}" ]; then
  log "ERROR: Archive Info.plist not found at ${ARCHIVE_PLIST}"
  exit 1
fi

if [ ! -d "${APP_PATH}" ] || [ ! -f "${APP_PLIST}" ]; then
  log "ERROR: Archived app not found at ${APP_PATH}"
  exit 1
fi

BUNDLE_ID="$(plist_print ':CFBundleIdentifier' "${APP_PLIST}")"
VERSION="$(plist_print ':CFBundleShortVersionString' "${APP_PLIST}")"
BUILD="$(plist_print ':CFBundleVersion' "${APP_PLIST}")"

if [ -z "${BUNDLE_ID}" ] || [ -z "${VERSION}" ] || [ -z "${BUILD}" ]; then
  log "ERROR: Missing CFBundleIdentifier/version/build in app Info.plist"
  exit 1
fi

# -dvv is required; -dv omits Authority lines on some Xcode/tooling versions.
SIGNING_ID="$(codesign -dvv "${APP_PATH}" 2>&1 | sed -n 's/^Authority=//p' | head -1 || true)"
TEAM_ID="$(security cms -D -i "${APP_PATH}/embedded.mobileprovision" 2>/dev/null \
  | plutil -extract TeamIdentifier.0 raw - 2>/dev/null || true)"
if [ -z "${TEAM_ID}" ]; then
  TEAM_ID="${TEAM_FALLBACK}"
fi

# Always keep Organizer grouping keys correct.
plist_set_or_add_string ":Name" "${APP_NAME}" "${ARCHIVE_PLIST}"
plist_set_or_add_string ":SchemeName" "${APP_NAME}" "${ARCHIVE_PLIST}"

if application_properties_valid "${ARCHIVE_PLIST}"; then
  # Fill optional keys if Xcode omitted them but core dict is already valid.
  if [ -n "${TEAM_ID}" ]; then
    plist_set_or_add_string ":ApplicationProperties:Team" "${TEAM_ID}" "${ARCHIVE_PLIST}"
  fi
  if [ -n "${SIGNING_ID}" ]; then
    plist_set_or_add_string ":ApplicationProperties:SigningIdentity" "${SIGNING_ID}" "${ARCHIVE_PLIST}"
  fi
  log "ApplicationProperties already valid; ensured Name/SchemeName/Team/SigningIdentity"
  log "=== fix-archive.sh finished (noop core) ==="
  exit 0
fi

log "ApplicationProperties missing or malformed; rebuilding nested dict"
log "  Bundle ID: ${BUNDLE_ID}"
log "  Version: ${VERSION}"
log "  Build: ${BUILD}"
log "  Team: ${TEAM_ID}"
log "  SigningIdentity: ${SIGNING_ID:-<unavailable>}"

# Remove any broken ApplicationProperties (or root-level leftovers from older fixes).
/usr/libexec/PlistBuddy -c "Delete :ApplicationProperties" "${ARCHIVE_PLIST}" 2>/dev/null || true
for root_key in ApplicationPath CFBundleIdentifier CFBundleShortVersionString CFBundleVersion SigningIdentity Team Architectures; do
  /usr/libexec/PlistBuddy -c "Delete :${root_key}" "${ARCHIVE_PLIST}" 2>/dev/null || true
done

/usr/libexec/PlistBuddy -c "Add :ApplicationProperties dict" "${ARCHIVE_PLIST}"
/usr/libexec/PlistBuddy -c "Add :ApplicationProperties:ApplicationPath string 'Applications/${APP_NAME}.app'" "${ARCHIVE_PLIST}"
/usr/libexec/PlistBuddy -c "Add :ApplicationProperties:CFBundleIdentifier string '${BUNDLE_ID}'" "${ARCHIVE_PLIST}"
/usr/libexec/PlistBuddy -c "Add :ApplicationProperties:CFBundleShortVersionString string '${VERSION}'" "${ARCHIVE_PLIST}"
/usr/libexec/PlistBuddy -c "Add :ApplicationProperties:CFBundleVersion string '${BUILD}'" "${ARCHIVE_PLIST}"

if [ -n "${TEAM_ID}" ]; then
  /usr/libexec/PlistBuddy -c "Add :ApplicationProperties:Team string '${TEAM_ID}'" "${ARCHIVE_PLIST}"
fi
if [ -n "${SIGNING_ID}" ]; then
  /usr/libexec/PlistBuddy -c "Add :ApplicationProperties:SigningIdentity string '${SIGNING_ID}'" "${ARCHIVE_PLIST}"
fi

if ! application_properties_valid "${ARCHIVE_PLIST}"; then
  log "ERROR: Failed to rebuild valid ApplicationProperties"
  exit 1
fi

log "ApplicationProperties rebuilt successfully"
log "=== fix-archive.sh finished ==="
exit 0
