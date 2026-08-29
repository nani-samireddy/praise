#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/run_wireless_flutter.sh [--mode debug|profile|release] [--hotreload|--prod] [--device HOST:PORT]

Modes:
  debug    Runs flutter run with hot reload support. Default.
  profile  Runs flutter run --profile.
  release  Runs flutter run --release.

Examples:
  scripts/run_wireless_flutter.sh
  scripts/run_wireless_flutter.sh --hotreload
  scripts/run_wireless_flutter.sh --prod
  scripts/run_wireless_flutter.sh --mode release
  scripts/run_wireless_flutter.sh --device 192.168.10.43:42009
EOF
}

mode="debug"
requested_device=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      mode="${2:-}"
      shift 2
      ;;
    --hotreload)
      mode="debug"
      shift
      ;;
    --prod)
      mode="release"
      shift
      ;;
    --device|-d)
      requested_device="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$mode" in
  debug|profile|release) ;;
  *)
    echo "--mode must be debug, profile, or release." >&2
    exit 2
    ;;
esac

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 is not installed or is not on PATH." >&2
    exit 1
  fi
}

require_command adb
require_command flutter

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

select_from_list() {
  local prompt="$1"
  shift
  local items=("$@")

  if [[ ${#items[@]} -eq 0 ]]; then
    return 1
  fi
  if [[ ${#items[@]} -eq 1 ]]; then
    printf '%s\n' "${items[0]}"
    return 0
  fi

  echo "$prompt" >&2
  local index=1
  for item in "${items[@]}"; do
    printf '  %d) %s\n' "$index" "$item" >&2
    index=$((index + 1))
  done

  local choice
  while true; do
    read -r -p "Select device [1-${#items[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] &&
      ((choice >= 1 && choice <= ${#items[@]})); then
      printf '%s\n' "${items[$((choice - 1))]}"
      return 0
    fi
    echo "Enter a number from 1 to ${#items[@]}." >&2
  done
}

discover_mdns_targets() {
  adb mdns services 2>/dev/null |
    awk '
      /_adb-tls-connect\._tcp/ {
        for (i = 1; i <= NF; i++) {
          if ($i ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$/) {
            print $i
          }
        }
      }
    ' |
    sort -u
}

connected_tcp_targets() {
  adb devices |
    awk '
      NR > 1 && $2 == "device" && $1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$/ {
        print $1
      }
    ' |
    sort -u
}

target="$requested_device"
if [[ -z "$target" ]]; then
  mapfile -t discovered < <(discover_mdns_targets)
  if [[ ${#discovered[@]} -gt 0 ]]; then
    target="$(select_from_list "Wireless Android devices discovered by adb mDNS:" "${discovered[@]}")"
  else
    mapfile -t connected < <(connected_tcp_targets)
    if [[ ${#connected[@]} -gt 0 ]]; then
      target="$(select_from_list "Already connected TCP Android devices:" "${connected[@]}")"
    else
      echo "No wireless adb targets were discovered." >&2
      echo "On the phone, enable Developer options > Wireless debugging." >&2
      echo "Open Wireless debugging and keep that screen visible." >&2
      read -r -p "Enter HOST:PORT manually, or leave blank to cancel: " target
      if [[ -z "$target" ]]; then
        exit 1
      fi
    fi
  fi
fi

if [[ ! "$target" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$ ]]; then
  echo "Device must look like HOST:PORT, for example 192.168.10.43:42009." >&2
  exit 2
fi

echo "Connecting adb to $target..."
connect_output="$(adb connect "$target" || true)"
echo "$connect_output"
if ! grep -Eiq 'connected|already connected' <<<"$connect_output"; then
  echo "adb could not connect to $target." >&2
  echo "If the phone port changed, reopen Wireless debugging and run this script again." >&2
  exit 1
fi

echo
echo "Connected devices:"
adb devices

flutter_args=(flutter run -d "$target")
case "$mode" in
  debug) ;;
  profile) flutter_args+=(--profile) ;;
  release) flutter_args+=(--release) ;;
esac

echo
if [[ "$mode" == "debug" ]]; then
  echo "Starting Flutter in debug mode. Hot reload is available with r in this terminal."
else
  echo "Starting Flutter in $mode mode."
fi
exec "${flutter_args[@]}"
