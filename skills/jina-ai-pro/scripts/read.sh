#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

usage() {
  cat <<'EOF'
Usage: read.sh "https://example.com" [--format content] [--wait-for-selector css] [--target-selector css] [--remove-selector css] [--retain-links mode] [--retain-images mode] [--with-generated-alt] [--with-links-summary] [--with-images-summary] [--timeout 30] [--no-cache] [--json] [--user-agent UA] [--ua-preset preset]

Read a URL with Jina AI Reader using curl.
EOF
}

TARGET_URL=""
FORMAT="content"
WAIT_FOR_SELECTOR=""
TARGET_SELECTOR=""
REMOVE_SELECTOR=""
RETAIN_LINKS=""
RETAIN_IMAGES=""
WITH_GENERATED_ALT=0
WITH_LINKS_SUMMARY=0
WITH_IMAGES_SUMMARY=0
TIMEOUT=30
NO_CACHE=0
JSON_MODE=0
USER_AGENT=""
UA_PRESET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --format)
      [[ $# -ge 2 ]] || die "missing value for $1"
      FORMAT="$2"
      shift 2
      ;;
    --wait-for-selector)
      [[ $# -ge 2 ]] || die "missing value for $1"
      WAIT_FOR_SELECTOR="$2"
      shift 2
      ;;
    --target-selector)
      [[ $# -ge 2 ]] || die "missing value for $1"
      TARGET_SELECTOR="$2"
      shift 2
      ;;
    --remove-selector)
      [[ $# -ge 2 ]] || die "missing value for $1"
      REMOVE_SELECTOR="$2"
      shift 2
      ;;
    --retain-links)
      [[ $# -ge 2 ]] || die "missing value for $1"
      RETAIN_LINKS="$2"
      shift 2
      ;;
    --retain-images)
      [[ $# -ge 2 ]] || die "missing value for $1"
      RETAIN_IMAGES="$2"
      shift 2
      ;;
    --with-generated-alt)
      WITH_GENERATED_ALT=1
      shift
      ;;
    --with-links-summary)
      WITH_LINKS_SUMMARY=1
      shift
      ;;
    --with-images-summary)
      WITH_IMAGES_SUMMARY=1
      shift
      ;;
    --timeout)
      [[ $# -ge 2 ]] || die "missing value for $1"
      TIMEOUT="$2"
      shift 2
      ;;
    --no-cache)
      NO_CACHE=1
      shift
      ;;
    --json)
      JSON_MODE=1
      shift
      ;;
    --user-agent)
      [[ $# -ge 2 ]] || die "missing value for $1"
      USER_AGENT="$2"
      shift 2
      ;;
    --ua-preset)
      [[ $# -ge 2 ]] || die "missing value for $1"
      UA_PRESET="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "unknown arg: $1"
      ;;
    *)
      if [[ -z "$TARGET_URL" ]]; then
        TARGET_URL="$1"
      else
        die "unexpected positional argument: $1"
      fi
      shift
      ;;
  esac
done

[[ -n "$TARGET_URL" ]] || {
  usage
  exit 2
}

case "$FORMAT" in
  content|markdown|text|html|pageshot|screenshot|vlm|readerlm-v2) ;;
  *) die "unsupported --format: $FORMAT" ;;
esac

is_positive_int "$TIMEOUT" || die "--timeout must be a positive integer"

load_dotenv "$SCRIPT_DIR"
API_KEY="${JINA_API_KEY:-}"
RESOLVED_UA="$(resolve_user_agent "$USER_AGENT" "$UA_PRESET" || true)"

BODY_FILE="$(mktemp)"
HEADER_FILE="$(mktemp)"
cleanup() {
  rm -f "$BODY_FILE" "$HEADER_FILE"
}
trap cleanup EXIT

run_request() {
  local include_auth="$1"
  : >"$BODY_FILE"
  : >"$HEADER_FILE"

  local -a cmd=(
    curl
    -sS
    --location
    --max-time "$TIMEOUT"
    --request POST
    "https://r.jina.ai/"
    --data-urlencode "url=$TARGET_URL"
    -D "$HEADER_FILE"
    -o "$BODY_FILE"
    -w "%{http_code}"
  )

  if (( JSON_MODE )); then
    cmd+=(-H "Accept: application/json")
  else
    cmd+=(-H "Accept: text/plain")
  fi

  if [[ "$FORMAT" != "content" ]]; then
    cmd+=(-H "X-Respond-With: $FORMAT")
  fi
  if [[ -n "$WAIT_FOR_SELECTOR" ]]; then
    cmd+=(-H "X-Wait-For-Selector: $WAIT_FOR_SELECTOR")
  fi
  if [[ -n "$TARGET_SELECTOR" ]]; then
    cmd+=(-H "X-Target-Selector: $TARGET_SELECTOR")
  fi
  if [[ -n "$REMOVE_SELECTOR" ]]; then
    cmd+=(-H "X-Remove-Selector: $REMOVE_SELECTOR")
  fi
  if [[ -n "$RETAIN_LINKS" ]]; then
    cmd+=(-H "X-Retain-Links: $RETAIN_LINKS")
  fi
  if [[ -n "$RETAIN_IMAGES" ]]; then
    cmd+=(-H "X-Retain-Images: $RETAIN_IMAGES")
  fi
  if (( WITH_GENERATED_ALT )); then
    cmd+=(-H "X-With-Generated-Alt: true")
  fi
  if (( WITH_LINKS_SUMMARY )); then
    cmd+=(-H "X-With-links-Summary: true")
  fi
  if (( WITH_IMAGES_SUMMARY )); then
    cmd+=(-H "X-With-Images-Summary: true")
  fi
  if (( NO_CACHE )); then
    cmd+=(-H "X-No-Cache: true")
  fi

  cmd+=(-H "X-Timeout: $TIMEOUT")

  if [[ -n "$RESOLVED_UA" ]]; then
    cmd+=(-A "$RESOLVED_UA" -H "X-User-Agent: $RESOLVED_UA")
  fi

  if [[ "$include_auth" == "1" && -n "$API_KEY" ]]; then
    cmd+=(-H "Authorization: Bearer $API_KEY")
  fi

  "${cmd[@]}"
}

STATUS_CODE="$(run_request 1)"

if [[ "$STATUS_CODE" =~ ^2[0-9][0-9]$ ]]; then
  cat "$BODY_FILE"
  exit 0
fi

if [[ "$STATUS_CODE" =~ ^(401|403)$ && -n "$API_KEY" ]]; then
  echo "warning: authenticated Jina request was rejected; retrying without auth" >&2
  STATUS_CODE="$(run_request 0)"
  if [[ "$STATUS_CODE" =~ ^2[0-9][0-9]$ ]]; then
    cat "$BODY_FILE"
    exit 0
  fi
fi

echo "error: Jina read failed ($STATUS_CODE): $(<"$BODY_FILE")" >&2
exit 1
