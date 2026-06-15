#!/usr/bin/env bash
set -euo pipefail

ASSERT_MODE=0
if [[ "${1:-}" == "--assert" ]]; then
  ASSERT_MODE=1
  shift
fi

BASE_URL="${1:-https://console.se7endot.top}"
API_BASE_URL="${2:-https://api.se7endot.top}"
EXISTING_ASSET_PATH="${CREATIVE_EXISTING_ASSET_PATH:-}"
FAILURES=()

trim_slash() {
  local value="$1"
  value="${value%/}"
  printf '%s' "$value"
}

sanitize_location() {
  local value="$1"
  if [[ -z "$value" ]]; then
    printf '%s' ""
    return
  fi
  value="${value%%#*}"
  if [[ "$value" == *\?* ]]; then
    printf '%s?<redacted>' "${value%%\?*}"
  else
    printf '%s' "$value"
  fi
}

add_failure() {
  FAILURES+=("$1")
}

auto_asset_path() {
  local tmp path
  tmp="$(mktemp)"
  path=""
  if curl -k -sS -o "$tmp" "$(trim_slash "$BASE_URL")/creative/"; then
    path="$(python3 - "$tmp" <<'PY'
import re, sys
text = open(sys.argv[1], errors='ignore').read()
match = re.search(r"/creative/assets/[^\"'\s>)]+", text)
print(match.group(0) if match else "")
PY
)"
  fi
  rm -f "$tmp"
  printf '%s' "$path"
}

probe() {
  local method="$1"
  local url="$2"
  local label="$3"
  local tmp_headers tmp_body status size content_type cache_control location xcto
  tmp_headers="$(mktemp)"
  tmp_body="$(mktemp)"
  status="000"
  size="0"
  if [[ "$method" == "HEAD" ]]; then
    status="$(curl -k -sS -o /dev/null -D "$tmp_headers" -w '%{http_code}' -I "$url" || true)"
    size="0"
  else
    status="$(curl -k -sS -o "$tmp_body" -D "$tmp_headers" -w '%{http_code}' "$url" || true)"
    size="$(wc -c < "$tmp_body" | tr -d ' ')"
  fi
  content_type="$(awk 'BEGIN{IGNORECASE=1}/^content-type:/{sub(/^[^:]+:[[:space:]]*/, ""); sub(/[[:space:]]*\r$/, ""); print; exit}' "$tmp_headers")"
  cache_control="$(awk 'BEGIN{IGNORECASE=1}/^cache-control:/{sub(/^[^:]+:[[:space:]]*/, ""); sub(/[[:space:]]*\r$/, ""); print; exit}' "$tmp_headers")"
  location="$(awk 'BEGIN{IGNORECASE=1}/^location:/{sub(/^[^:]+:[[:space:]]*/, ""); sub(/[[:space:]]*\r$/, ""); print; exit}' "$tmp_headers")"
  location="$(sanitize_location "$location")"
  xcto="$(awk 'BEGIN{IGNORECASE=1}/^x-content-type-options:/{sub(/^[^:]+:[[:space:]]*/, ""); sub(/[[:space:]]*\r$/, ""); print; exit}' "$tmp_headers")"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$label" "$method" "$status" "$content_type" "$cache_control" "$location" "$xcto" "$size"
  rm -f "$tmp_headers" "$tmp_body"
  PROBE_STATUS="$status"
  PROBE_CONTENT_TYPE="$content_type"
  PROBE_CACHE_CONTROL="$cache_control"
  PROBE_LOCATION="$location"
}

expect_status() {
  local label="$1" want="$2"
  [[ "$PROBE_STATUS" == "$want" ]] || add_failure "$label expected status $want got $PROBE_STATUS"
}

expect_status_regex() {
  local label="$1" regex="$2"
  [[ "$PROBE_STATUS" =~ $regex ]] || add_failure "$label expected status /$regex/ got $PROBE_STATUS"
}

expect_type_regex() {
  local label="$1" regex="$2"
  [[ "${PROBE_CONTENT_TYPE,,}" =~ $regex ]] || add_failure "$label expected content-type /$regex/ got ${PROBE_CONTENT_TYPE:-<empty>}"
}

expect_no_html() {
  local label="$1"
  [[ ! "${PROBE_CONTENT_TYPE,,}" =~ text/html ]] || add_failure "$label must not return text/html"
}

expect_cache_no_store() {
  local label="$1"
  [[ "${PROBE_CACHE_CONTROL,,}" == *no-store* ]] || add_failure "$label expected cache-control containing no-store got ${PROBE_CACHE_CONTROL:-<empty>}"
}

BASE_URL="$(trim_slash "$BASE_URL")"
API_BASE_URL="$(trim_slash "$API_BASE_URL")"
if [[ -z "$EXISTING_ASSET_PATH" ]]; then
  EXISTING_ASSET_PATH="$(auto_asset_path)"
fi

printf 'label\tmethod\tstatus\tcontent-type\tcache-control\tlocation\tx-content-type-options\tsize\n'
probe GET "$BASE_URL/creative/" creative-app-shell
if (( ASSERT_MODE )); then expect_status creative-app-shell 200; expect_type_regex creative-app-shell 'text/html'; fi

probe GET "$BASE_URL/creative/sw.js" creative-service-worker
if (( ASSERT_MODE )); then expect_status creative-service-worker 200; expect_type_regex creative-service-worker 'javascript|ecmascript'; fi

probe GET "$BASE_URL/creative/version.json" creative-version-json
if (( ASSERT_MODE )); then expect_status creative-version-json 200; expect_type_regex creative-version-json 'json'; fi

if [[ -n "$EXISTING_ASSET_PATH" ]]; then
  probe GET "$BASE_URL$EXISTING_ASSET_PATH" creative-existing-asset
  if (( ASSERT_MODE )); then expect_status creative-existing-asset 200; expect_no_html creative-existing-asset; fi
else
  printf 'creative-existing-asset\tSKIP\t-\tno /creative/assets/* reference found in /creative/\t-\t-\t-\t-\n'
  if (( ASSERT_MODE )); then add_failure 'creative-existing-asset could not auto-discover a real /creative/assets/* path'; fi
fi

probe GET "$BASE_URL/creative/assets/__missing_release_check__.js" creative-missing-asset
if (( ASSERT_MODE )); then expect_status_regex creative-missing-asset '^(404|403)$'; expect_no_html creative-missing-asset; fi

probe GET "$BASE_URL/creative/api/bootstrap" creative-bootstrap-unauth
if (( ASSERT_MODE )); then expect_status_regex creative-bootstrap-unauth '^(401|403)$'; expect_type_regex creative-bootstrap-unauth 'json'; expect_cache_no_store creative-bootstrap-unauth; fi

probe GET "$BASE_URL/creative/relay/v1/chat/completions" creative-relay-wrong-method
if (( ASSERT_MODE )); then expect_status_regex creative-relay-wrong-method '^(401|403|404|405)$'; expect_no_html creative-relay-wrong-method; expect_cache_no_store creative-relay-wrong-method; fi

probe GET "$API_BASE_URL/v1/models" existing-api-models-unauth
if (( ASSERT_MODE )); then expect_status existing-api-models-unauth 401; expect_type_regex existing-api-models-unauth 'json'; fi

probe GET "$BASE_URL/login" existing-console-login
if (( ASSERT_MODE )); then expect_status existing-console-login 200; expect_type_regex existing-console-login 'text/html'; fi

if (( ASSERT_MODE )) && ((${#FAILURES[@]} > 0)); then
  printf '\nFAILURES:\n' >&2
  printf -- '- %s\n' "${FAILURES[@]}" >&2
  exit 1
fi
