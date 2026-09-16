#!/usr/bin/env sh
set -eu

usage() {
  cat <<'EOF'
Usage:
  scripts/run_wireless_flutter.sh [--mode debug|profile|release] [--hotreload|--prod] [--device SERIAL|HOST:PORT]

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
  scripts/run_wireless_flutter.sh --device emulator-5554
EOF
}

mode="debug"
requested_device=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode)
      if [ "$#" -lt 2 ]; then
        echo "--mode requires a value." >&2
        exit 2
      fi
      mode="$2"
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
      if [ "$#" -lt 2 ]; then
        echo "--device requires a device serial or HOST:PORT value." >&2
        exit 2
      fi
      requested_device="$2"
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

add_android_platform_tools_to_path() {
  command -v adb >/dev/null 2>&1 && return 0

  try_android_sdk "${ANDROID_HOME-}" && return 0
  try_android_sdk "${ANDROID_SDK_ROOT-}" && return 0

  platform=$(uname -s 2>/dev/null || printf 'unknown')
  case "$platform" in
    Darwin)
      try_android_sdk "${HOME-}/Library/Android/sdk" && return 0
      ;;
    Linux)
      try_android_sdk "${HOME-}/Android/Sdk" && return 0
      try_android_sdk "${HOME-}/.android/sdk" && return 0
      ;;
    MINGW*|MSYS*|CYGWIN*)
      try_android_sdk "${LOCALAPPDATA-}/Android/Sdk" && return 0
      try_android_sdk "${USERPROFILE-}/AppData/Local/Android/Sdk" && return 0
      try_android_sdk "${HOME-}/AppData/Local/Android/Sdk" && return 0
      ;;
    *)
      try_android_sdk "${HOME-}/Library/Android/sdk" && return 0
      try_android_sdk "${HOME-}/Android/Sdk" && return 0
      ;;
  esac
  return 1
}

normalize_sdk_path() {
  sdk_path="$1"
  case "$sdk_path" in
    [A-Za-z]:*|*\\*)
      if command -v cygpath >/dev/null 2>&1; then
        cygpath -u "$sdk_path"
        return 0
      fi
      ;;
  esac
  printf '%s\n' "$sdk_path"
}

try_android_sdk() {
  sdk_path="$1"
  [ -n "$sdk_path" ] || return 1
  sdk_path=$(normalize_sdk_path "$sdk_path")
  platform_tools="$sdk_path/platform-tools"
  if [ -x "$platform_tools/adb" ] || [ -x "$platform_tools/adb.exe" ]; then
    PATH="$platform_tools:$PATH"
    export PATH
    return 0
  fi
  return 1
}

add_android_platform_tools_to_path
require_command adb
require_command flutter

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

select_from_list() {
  prompt="$1"
  shift

  if [ "$#" -eq 0 ]; then
    return 1
  fi
  echo "$prompt" >&2
  index=1
  for item do
    printf '  %s) %s\n' "$index" "$item" >&2
    index=$((index + 1))
  done

  while :; do
    printf 'Select device [1-%s]: ' "$#" >&2
    IFS= read -r choice
    case "$choice" in
      ''|*[!0-9]*) ;;
      *)
        index=1
        for item do
          if [ "$choice" -eq "$index" ]; then
            printf '%s\n' "$item"
            return 0
          fi
          index=$((index + 1))
        done
        ;;
    esac
    echo "Enter a number from 1-$#." >&2
  done
}

discover_mdns_services() {
  adb mdns services 2>/dev/null |
    awk '/_adb-tls-(connect|pairing)\._tcp/'
}

discover_mdns_targets() {
  discover_mdns_services |
    awk '/_adb-tls-connect\._tcp/ { print $3 }' |
    sort -u
}

discover_mdns_pairing_targets() {
  discover_mdns_services |
    awk '/_adb-tls-pairing\._tcp/ { print $3 }' |
    sort -u
}

connected_device_targets() {
  adb devices |
    awk '
      NR > 1 && $2 == "device" {
        print $1
      }
    ' |
    sort -u
}

show_available_devices() {
  echo "Available Android devices:"
  device_lines=$(adb devices -l | awk '
    NR == 1 { next }
    NF >= 2 {
      model = ""
      for (i = 3; i <= NF; i++) {
        if ($i ~ /^model:/) {
          model = substr($i, 7)
          gsub("_", " ", model)
        }
      }
      if (model != "") {
        printf "  %s [%s] %s\n", $1, $2, model
      } else {
        printf "  %s [%s]\n", $1, $2
      }
    }
  ')
  if [ -n "$device_lines" ]; then
    printf '%s\n' "$device_lines"
  else
    echo "  None currently connected."
  fi

  mdns_services=$(discover_mdns_services)
  if [ -n "$mdns_services" ]; then
    echo "Wireless debugging services discovered:"
    printf '%s\n' "$mdns_services" |
      awk '
        /_adb-tls-connect\._tcp/ { printf "  Connect: %s (%s)\n", $1, $3 }
        /_adb-tls-pairing\._tcp/ { printf "  Pair:    %s (%s)\n", $1, $3 }
      '
  fi
}

is_host_port_target() {
  printf '%s\n' "$1" | grep -Eq '^[^:[:space:]]+:[0-9]+$'
}

target_is_in_list() {
  selected_target="$1"
  shift
  for available_target do
    [ "$selected_target" = "$available_target" ] && return 0
  done
  return 1
}

connect_to_target() {
  target_to_connect="$1"
  echo "Connecting adb to $target_to_connect..."
  connect_output=$(adb connect "$target_to_connect" 2>&1 || true)
  echo "$connect_output"
  printf '%s\n' "$connect_output" | grep -Eiq 'connected|already connected'
}

refresh_adb_discovery() {
  echo "Refreshing ADB wireless discovery..."
  adb kill-server >/dev/null 2>&1 || true
  adb start-server >/dev/null 2>&1 || true
}

target="$requested_device"
if [ -z "$target" ]; then
  show_available_devices

  available_targets=$(connected_device_targets)
  discovered=$(discover_mdns_targets)
  for discovered_target in $discovered; do
    case " $available_targets " in
      *" $discovered_target "*) ;;
      *)
        if [ -n "$available_targets" ]; then
          available_targets="$available_targets $discovered_target"
        else
          available_targets="$discovered_target"
        fi
        ;;
    esac
  done

  if [ -n "$available_targets" ]; then
    target=$(select_from_list "Select an Android device:" $available_targets)
  else
    echo "No Android devices were discovered." >&2
    echo "On the phone, enable Developer options > Wireless debugging." >&2
    echo "Open Wireless debugging and keep that screen visible." >&2
    printf 'Enter HOST:PORT manually, or leave blank to cancel: ' >&2
    IFS= read -r target
    [ -n "$target" ] || exit 1
  fi
fi

if is_host_port_target "$target"; then
  if ! connect_to_target "$target"; then
    refresh_adb_discovery
    refreshed_targets=$(discover_mdns_targets)
    if ! target_is_in_list "$target" $refreshed_targets && [ -n "$refreshed_targets" ]; then
      target=$(select_from_list "The wireless endpoint changed. Select the refreshed endpoint:" $refreshed_targets)
    fi

    if ! connect_to_target "$target"; then
      pairing_targets=$(discover_mdns_pairing_targets)
      if [ -n "$pairing_targets" ]; then
        pairing_target=$(select_from_list "Pair this Android device first:" $pairing_targets)
        printf 'Enter the pairing code shown on the phone: ' >&2
        IFS= read -r pairing_code
        pair_output=$(adb pair "$pairing_target" "$pairing_code" 2>&1 || true)
        echo "$pair_output"
        if printf '%s\n' "$pair_output" | grep -Eiq 'success|paired'; then
          target=$(select_from_list "Select the connection endpoint:" $(discover_mdns_targets))
          if ! connect_to_target "$target"; then
            echo "ADB pairing succeeded, but the connection endpoint still failed." >&2
            exit 1
          fi
        else
          echo "ADB pairing failed." >&2
          exit 1
        fi
      else
        echo "adb could not connect to $target." >&2
        echo "The phone is advertising a connection port, but no pairing service is available." >&2
        echo "On the phone, open Wireless debugging > Pair device with pairing code, then run this script again." >&2
        exit 1
      fi
    fi
  fi
else
  device_state=$(adb devices | awk -v selected="$target" '$1 == selected { print $2 }')
  if [ "$device_state" != "device" ]; then
    echo "Selected device '$target' is not ready for Flutter (state: ${device_state:-missing})." >&2
    exit 1
  fi
fi

echo
echo "Connected devices:"
adb devices -l

echo
if [ "$mode" = "debug" ]; then
  echo "Starting Flutter in debug mode. Hot reload is available with r in this terminal."
  exec flutter run -d "$target"
fi
echo "Starting Flutter in $mode mode."
if [ "$mode" = "profile" ]; then
  exec flutter run -d "$target" --profile
fi
exec flutter run -d "$target" --release
