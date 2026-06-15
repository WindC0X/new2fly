#!/usr/bin/env bash
set -euo pipefail
umask 077

PHASE=""
BASE_URL="https://console.se7endot.top"

usage() {
  cat <<'USAGE'
Usage:
  creative-cloud-sync-smoke.sh --phase disabled|enabled [base-url]

Purpose:
  No-secret authenticated Creative 云同步 smoke for embedded /creative/.

Inputs:
  CREATIVE_SMOKE_USERNAME  Optional. If omitted, prompted without echoing password.
  CREATIVE_SMOKE_PASSWORD  Optional. Prefer prompt/stdin secret channel over shell history.
  CURL_INSECURE=1          Optional. Adds curl -k for private/self-signed targets.

Output policy:
  Prints only statuses and sanitized generated IDs. Never prints password, cookies,
  CSRF, nonce, response bodies, asset bytes, or provider/storage credentials.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase)
      PHASE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      BASE_URL="$1"
      shift
      ;;
  esac
done

if [[ "$PHASE" != "disabled" && "$PHASE" != "enabled" ]]; then
  usage >&2
  exit 2
fi

trim_slash() {
  local value="$1"
  value="${value%/}"
  printf '%s' "$value"
}

origin_for() {
  python3 - "$1" <<'PY'
from urllib.parse import urlsplit
import sys
u = urlsplit(sys.argv[1])
if not u.scheme or not u.netloc:
    raise SystemExit("invalid base url")
print(f"{u.scheme}://{u.netloc}")
PY
}

json_get() {
  python3 - "$1" "$2" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8', errors='replace') as fh:
    data = json.load(fh)
cur = data
for part in sys.argv[2].split('.'):
    if isinstance(cur, dict) and part in cur:
        cur = cur[part]
    else:
        print("")
        raise SystemExit(0)
if isinstance(cur, bool):
    print("true" if cur else "false")
elif cur is None:
    print("")
else:
    print(str(cur))
PY
}

require_json_success() {
  local file="$1" label="$2"
  local success
  success="$(json_get "$file" success 2>/dev/null || true)"
  [[ "$success" == "true" ]] || die "$label returned JSON success=$success"
}

require_status() {
  local label="$1" got="$2" want="$3"
  [[ "$got" == "$want" ]] || die "$label expected status $want got $got"
}

require_status_regex() {
  local label="$1" got="$2" regex="$3"
  [[ "$got" =~ $regex ]] || die "$label expected status /$regex/ got $got"
}

die() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

BASE_URL="$(trim_slash "$BASE_URL")"
ORIGIN="$(origin_for "$BASE_URL")"
CURL_ARGS=(-sS)
if [[ "${CURL_INSECURE:-0}" == "1" ]]; then
  CURL_ARGS+=(-k)
fi

USERNAME="${CREATIVE_SMOKE_USERNAME:-}"
PASSWORD="${CREATIVE_SMOKE_PASSWORD:-}"
if [[ -z "$USERNAME" ]]; then
  read -r -p "New API username: " USERNAME
fi
if [[ -z "$PASSWORD" ]]; then
  read -r -s -p "New API password: " PASSWORD
  printf '\n'
fi
[[ -n "$USERNAME" && -n "$PASSWORD" ]] || die "username/password are required"

WORK_DIR="$(mktemp -d)"
COOKIE_JAR="$WORK_DIR/cookies.txt"
cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

LOGIN_JSON="$WORK_DIR/login.json"
LOGIN_INPUT="$WORK_DIR/login-input.txt"
{
  printf '%s\n' "$USERNAME"
  printf '%s\n' "$PASSWORD"
} > "$LOGIN_INPUT"
python3 - "$LOGIN_INPUT" > "$LOGIN_JSON" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as fh:
    username = fh.readline().rstrip('\n')
    pwd_value = fh.readline().rstrip('\n')
json.dump({"username": username, "password": pwd_value}, sys.stdout)
PY
rm -f "$LOGIN_INPUT"
unset PASSWORD CREATIVE_SMOKE_PASSWORD

LOGIN_RESP="$WORK_DIR/login-response.json"
LOGIN_STATUS="$(curl "${CURL_ARGS[@]}" -o "$LOGIN_RESP" -w '%{http_code}' \
  -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
  -H 'Content-Type: application/json' \
  --data-binary "@$LOGIN_JSON" \
  "$BASE_URL/api/user/login?turnstile=" || true)"
printf 'login_status=%s\n' "$LOGIN_STATUS"
require_status login "$LOGIN_STATUS" 200
require_json_success "$LOGIN_RESP" login
if [[ "$(json_get "$LOGIN_RESP" data.require_2fa 2>/dev/null || true)" == "true" ]]; then
  die "login requires 2FA; use a dedicated smoke account without 2FA or run a separate approved 2FA flow"
fi

BOOTSTRAP_RESP="$WORK_DIR/bootstrap.json"
BOOTSTRAP_STATUS="$(curl "${CURL_ARGS[@]}" -o "$BOOTSTRAP_RESP" -w '%{http_code}' \
  -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
  "$BASE_URL/creative/api/bootstrap" || true)"
printf 'bootstrap_status=%s\n' "$BOOTSTRAP_STATUS"
require_status bootstrap "$BOOTSTRAP_STATUS" 200
require_json_success "$BOOTSTRAP_RESP" bootstrap
CSRF="$(json_get "$BOOTSTRAP_RESP" data.auth.csrfToken)"
NONCE="$(json_get "$BOOTSTRAP_RESP" data.auth.nonce)"
ASSET_ENABLED="$(json_get "$BOOTSTRAP_RESP" data.assetSync.enabled)"
if [[ -z "$ASSET_ENABLED" ]]; then
  ASSET_ENABLED="$(json_get "$BOOTSTRAP_RESP" data.assetSyncEnabled)"
fi
[[ -n "$CSRF" && -n "$NONCE" ]] || die "bootstrap did not return Creative auth material"
printf 'asset_sync_enabled=%s\n' "$ASSET_ENABLED"

AUTH_HEADER_CONFIG="$WORK_DIR/creative-auth-headers.curl"
BAD_NONCE_HEADER_CONFIG="$WORK_DIR/creative-bad-nonce-headers.curl"
cat > "$AUTH_HEADER_CONFIG" <<EOF
header = "Origin: $ORIGIN"
header = "X-Creative-CSRF: $CSRF"
header = "X-Creative-Nonce: $NONCE"
EOF
cat > "$BAD_NONCE_HEADER_CONFIG" <<EOF
header = "Origin: $ORIGIN"
header = "X-Creative-CSRF: $CSRF"
header = "X-Creative-Nonce: wrong-nonce"
EOF

PNG_FILE="$WORK_DIR/smoke.png"
base64 -d > "$PNG_FILE" <<'PNG'
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/l7nY2QAAAABJRU5ErkJggg==
PNG

if [[ "$PHASE" == "disabled" ]]; then
  [[ "$ASSET_ENABLED" == "false" ]] || die "Phase 1 expected asset sync disabled, got $ASSET_ENABLED"
  DISABLED_RESP="$WORK_DIR/disabled-upload.json"
  DISABLED_STATUS="$(curl "${CURL_ARGS[@]}" -o "$DISABLED_RESP" -w '%{http_code}' \
    -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
    -K "$AUTH_HEADER_CONFIG" \
    -F "file=@$PNG_FILE;type=image/png" -F "mediaType=image" \
    "$BASE_URL/creative/api/assets" || true)"
  printf 'disabled_asset_upload_status=%s\n' "$DISABLED_STATUS"
  require_status_regex disabled_asset_upload "$DISABLED_STATUS" '^(403|503)$'
  printf 'creative_cloud_sync_smoke=pass phase=disabled\n'
  exit 0
fi

[[ "$ASSET_ENABLED" == "true" ]] || die "Phase 2 expected asset sync enabled, got $ASSET_ENABLED"

DOC_ID="creative-smoke-$(date +%Y%m%d%H%M%S)-$RANDOM"
CREATE_JSON="$WORK_DIR/create-doc.json"
python3 - "$DOC_ID" > "$CREATE_JSON" <<'PY'
import json, sys
doc_id = sys.argv[1]
json.dump({
    "id": doc_id,
    "title": "Creative production smoke document",
    "snapshot": {"version": 1, "elements": []},
    "metadata": {"smoke": True, "source": "creative-cloud-sync-smoke"},
    "clientMutationId": doc_id + "-create",
}, sys.stdout)
PY

BAD_NONCE_RESP="$WORK_DIR/bad-nonce.json"
BAD_NONCE_STATUS="$(curl "${CURL_ARGS[@]}" -o "$BAD_NONCE_RESP" -w '%{http_code}' \
  -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
  -H 'Content-Type: application/json' -K "$BAD_NONCE_HEADER_CONFIG" \
  --data-binary "@$CREATE_JSON" \
  "$BASE_URL/creative/api/documents" || true)"
printf 'bad_nonce_status=%s\n' "$BAD_NONCE_STATUS"
require_status bad_nonce "$BAD_NONCE_STATUS" 403

CREATE_RESP="$WORK_DIR/create-doc-response.json"
CREATE_STATUS="$(curl "${CURL_ARGS[@]}" -o "$CREATE_RESP" -w '%{http_code}' \
  -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
  -H 'Content-Type: application/json' -K "$AUTH_HEADER_CONFIG" \
  --data-binary "@$CREATE_JSON" \
  "$BASE_URL/creative/api/documents" || true)"
printf 'document_create_status=%s\n' "$CREATE_STATUS"
require_status_regex document_create "$CREATE_STATUS" '^(200|201)$'
require_json_success "$CREATE_RESP" document_create
DOC_REVISION="$(json_get "$CREATE_RESP" data.document.revision)"
[[ -n "$DOC_REVISION" ]] || die "document create response did not include revision"

GET_DOC_RESP="$WORK_DIR/get-doc.json"
GET_DOC_STATUS="$(curl "${CURL_ARGS[@]}" -o "$GET_DOC_RESP" -w '%{http_code}' \
  -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
  "$BASE_URL/creative/api/documents/$DOC_ID" || true)"
printf 'document_get_status=%s\n' "$GET_DOC_STATUS"
require_status document_get "$GET_DOC_STATUS" 200
require_json_success "$GET_DOC_RESP" document_get

UPDATE_JSON="$WORK_DIR/update-doc.json"
python3 - "$DOC_REVISION" "$DOC_ID" > "$UPDATE_JSON" <<'PY'
import json, sys
json.dump({
    "baseRevision": int(sys.argv[1]),
    "title": "Creative production smoke document updated",
    "snapshot": {"version": 2, "elements": []},
    "metadata": {"smoke": True, "updated": True},
    "clientMutationId": sys.argv[2] + "-update",
}, sys.stdout)
PY
UPDATE_RESP="$WORK_DIR/update-doc-response.json"
UPDATE_STATUS="$(curl "${CURL_ARGS[@]}" -o "$UPDATE_RESP" -w '%{http_code}' \
  -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
  -X PUT -H 'Content-Type: application/json' -K "$AUTH_HEADER_CONFIG" \
  --data-binary "@$UPDATE_JSON" \
  "$BASE_URL/creative/api/documents/$DOC_ID" || true)"
printf 'document_update_status=%s\n' "$UPDATE_STATUS"
require_status document_update "$UPDATE_STATUS" 200
require_json_success "$UPDATE_RESP" document_update
DOC_REVISION="$(json_get "$UPDATE_RESP" data.document.revision)"
[[ -n "$DOC_REVISION" ]] || die "document update response did not include revision"

LIST_RESP="$WORK_DIR/list-docs.json"
LIST_STATUS="$(curl "${CURL_ARGS[@]}" -o "$LIST_RESP" -w '%{http_code}' \
  -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
  "$BASE_URL/creative/api/documents" || true)"
printf 'document_list_status=%s\n' "$LIST_STATUS"
require_status document_list "$LIST_STATUS" 200
require_json_success "$LIST_RESP" document_list

UPLOAD_RESP="$WORK_DIR/upload-asset.json"
UPLOAD_STATUS="$(curl "${CURL_ARGS[@]}" -o "$UPLOAD_RESP" -w '%{http_code}' \
  -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
  -K "$AUTH_HEADER_CONFIG" \
  -F "file=@$PNG_FILE;type=image/png" -F "mediaType=image" -F "clientAssetId=$DOC_ID-asset" \
  "$BASE_URL/creative/api/assets" || true)"
printf 'asset_upload_status=%s\n' "$UPLOAD_STATUS"
require_status_regex asset_upload "$UPLOAD_STATUS" '^(200|201)$'
require_json_success "$UPLOAD_RESP" asset_upload
ASSET_ID="$(json_get "$UPLOAD_RESP" data.asset.id)"
ASSET_URL="$(json_get "$UPLOAD_RESP" data.asset.url)"
[[ -n "$ASSET_ID" ]] || die "asset upload response did not include asset id"
[[ "$ASSET_URL" == /creative/api/assets/*/content ]] || die "asset url is not same-origin /creative/api/assets/:id/content"
[[ "$ASSET_URL" != *://* ]] || die "asset url unexpectedly contains a scheme"
printf 'asset_id_prefix=%s\n' "${ASSET_ID:0:12}"

META_RESP="$WORK_DIR/asset-meta.json"
META_STATUS="$(curl "${CURL_ARGS[@]}" -o "$META_RESP" -w '%{http_code}' \
  -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
  "$BASE_URL/creative/api/assets/$ASSET_ID" || true)"
printf 'asset_meta_status=%s\n' "$META_STATUS"
require_status asset_meta "$META_STATUS" 200
require_json_success "$META_RESP" asset_meta

RANGE_STATUS="$(curl "${CURL_ARGS[@]}" -o /dev/null -w '%{http_code}' \
  -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
  -H 'Range: bytes=0-7' \
  "$BASE_URL/creative/api/assets/$ASSET_ID/content" || true)"
printf 'asset_range_status=%s\n' "$RANGE_STATUS"
require_status asset_range "$RANGE_STATUS" 206

DELETE_ASSET_RESP="$WORK_DIR/delete-asset.json"
DELETE_ASSET_STATUS="$(curl "${CURL_ARGS[@]}" -o "$DELETE_ASSET_RESP" -w '%{http_code}' \
  -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
  -X DELETE -K "$AUTH_HEADER_CONFIG" \
  "$BASE_URL/creative/api/assets/$ASSET_ID" || true)"
printf 'asset_delete_status=%s\n' "$DELETE_ASSET_STATUS"
require_status asset_delete "$DELETE_ASSET_STATUS" 200
require_json_success "$DELETE_ASSET_RESP" asset_delete

DELETE_DOC_JSON="$WORK_DIR/delete-doc.json"
python3 - "$DOC_REVISION" > "$DELETE_DOC_JSON" <<'PY'
import json, sys
json.dump({"baseRevision": int(sys.argv[1])}, sys.stdout)
PY
DELETE_DOC_RESP="$WORK_DIR/delete-doc-response.json"
DELETE_DOC_STATUS="$(curl "${CURL_ARGS[@]}" -o "$DELETE_DOC_RESP" -w '%{http_code}' \
  -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
  -X DELETE -H 'Content-Type: application/json' -K "$AUTH_HEADER_CONFIG" \
  --data-binary "@$DELETE_DOC_JSON" \
  "$BASE_URL/creative/api/documents/$DOC_ID" || true)"
printf 'document_delete_status=%s\n' "$DELETE_DOC_STATUS"
require_status document_delete "$DELETE_DOC_STATUS" 200
require_json_success "$DELETE_DOC_RESP" document_delete

printf 'document_id=%s\n' "$DOC_ID"
printf 'creative_cloud_sync_smoke=pass phase=enabled\n'
