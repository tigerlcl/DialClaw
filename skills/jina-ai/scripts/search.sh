#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

usage() {
  cat <<'EOF'
Usage: search.sh "query" [-n 5] [--site domain] [--timeout 30] [--no-cache] [--json] [--user-agent UA] [--ua-preset preset]

Search the web with Jina AI Reader using curl.
EOF
}

QUERY=""
COUNT=5
TIMEOUT=30
NO_CACHE=0
JSON_MODE=0
USER_AGENT=""
UA_PRESET=""
SITES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -n|--count)
      [[ $# -ge 2 ]] || die "missing value for $1"
      COUNT="$2"
      shift 2
      ;;
    --site)
      [[ $# -ge 2 ]] || die "missing value for $1"
      SITES+=("$2")
      shift 2
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
      if [[ -z "$QUERY" ]]; then
        QUERY="$1"
      else
        die "unexpected positional argument: $1"
      fi
      shift
      ;;
  esac
done

[[ -n "$QUERY" ]] || {
  usage
  exit 2
}

is_positive_int "$COUNT" || die "--count must be a positive integer"
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
    --request GET
    "https://s.jina.ai/search"
    --get
    --data-urlencode "q=$QUERY"
    --data "count=$COUNT"
    -D "$HEADER_FILE"
    -o "$BODY_FILE"
    -w "%{http_code}"
  )

  local site
  for site in "${SITES[@]}"; do
    cmd+=(--data-urlencode "site=$site")
  done

  if (( JSON_MODE )); then
    cmd+=(-H "Accept: application/json")
  else
    cmd+=(-H "Accept: text/plain")
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

echo "error: Jina search failed ($STATUS_CODE): $(<"$BODY_FILE")" >&2
exit 1
