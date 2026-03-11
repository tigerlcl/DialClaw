#!/usr/bin/env bash

set -euo pipefail

readonly JINA_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

die() {
  echo "error: $*" >&2
  exit 1
}

find_dotenv() {
  local dir="$1"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/.env" ]]; then
      printf '%s\n' "$dir/.env"
      return 0
    fi
    dir="$(dirname "$dir")"
  done

  if [[ -f "/.env" ]]; then
    printf '%s\n' "/.env"
    return 0
  fi

  return 1
}

load_dotenv() {
  local env_file=""
  if env_file="$(find_dotenv "$1")"; then
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
  fi
}

ua_preset_value() {
  case "$1" in
    chrome-windows)
      printf '%s\n' "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36"
      ;;
    chrome-linux)
      printf '%s\n' "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36"
      ;;
    safari-macos)
      printf '%s\n' "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"
      ;;
    safari-ios)
      printf '%s\n' "Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1"
      ;;
    firefox-linux)
      printf '%s\n' "Mozilla/5.0 (X11; Linux x86_64; rv:135.0) Gecko/20100101 Firefox/135.0"
      ;;
    *)
      die "unknown ua preset: $1"
      ;;
  esac
}

resolve_user_agent() {
  local explicit_ua="${1:-}"
  local preset="${2:-}"
  local env_ua="${JINA_USER_AGENT:-}"

  if [[ -n "$explicit_ua" ]]; then
    printf '%s\n' "$explicit_ua"
    return 0
  fi

  if [[ -n "$preset" ]]; then
    ua_preset_value "$preset"
    return 0
  fi

  if [[ -n "$env_ua" ]]; then
    printf '%s\n' "$env_ua"
    return 0
  fi

  return 1
}

is_positive_int() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}
