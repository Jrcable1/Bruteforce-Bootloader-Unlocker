#!/usr/bin/env bash
# ==============================================================================
# fastboot_client.sh - Fastboot transport, device discovery, and command dispatcher
# ==============================================================================

[[ -n "${FASTBOOT_CLIENT_INCLUDED:-}" ]] && return 0
readonly FASTBOOT_CLIENT_INCLUDED=1

function find_fastboot_binary {
  local candidate="${FASTBOOT_BIN:-fastboot}"

  if command -v "${candidate}" >/dev/null 2>&1; then
    printf "%s" "${candidate}"
    return 0
  fi

  if [[ "${candidate}" == "fastboot" ]] && command -v fastboot.exe >/dev/null 2>&1; then
    printf "fastboot.exe"
    return 0
  fi

  printf ""
}

function verify_host_dependencies {
  ACTIVE_FASTBOOT_BIN=$(find_fastboot_binary)

  if [[ -z "${ACTIVE_FASTBOOT_BIN}" ]]; then
    ui_fail "fastboot binary not found in PATH."
    printf "  Linux:   sudo apt-get install android-tools-fastboot\n"
    printf "  macOS:   brew install android-platform-tools\n"
    printf "  Windows: add platform-tools to PATH or pass FASTBOOT_BIN=fastboot.exe\n"
    return 1
  fi

  local fb_ver adb_ver
  fb_ver=$("${ACTIVE_FASTBOOT_BIN}" --version 2>/dev/null | tr -d '\r' | sed -n '1p')
  ui_ok "fastboot detected: ${ACTIVE_FASTBOOT_BIN} (${fb_ver:-unknown})"

  if command -v adb >/dev/null 2>&1; then
    adb_ver=$(adb --version 2>/dev/null | tr -d '\r' | sed -n '1p')
    ui_ok "adb detected: ${adb_ver:-unknown}"
  else
    ui_warn "adb not found in PATH (optional, used for 'adb reboot bootloader')"
  fi

  return 0
}

function query_fastboot_device_list {
  "${ACTIVE_FASTBOOT_BIN}" devices 2>/dev/null | tr -d '\r' | awk 'NF >= 2 {print $1}'
}

function resolve_target_device {
  local manual_override=$1 device_list count first_device

  if [[ -n "${manual_override}" ]]; then
    TARGET_DEVICE_ID="${manual_override}"
  else
    device_list=$(query_fastboot_device_list)
    count=$(printf "%s\n" "${device_list}" | grep -c . || true)
    first_device=$(printf "%s\n" "${device_list}" | sed -n '1p')

    if [[ "${count}" -eq 0 ]]; then
      ui_fail "No device detected in Fastboot mode. Hard safety stop."
      printf "  1. Enable Developer Options & OEM Unlocking on device\n"
      printf "  2. Boot device into Fastboot mode ('adb reboot bootloader')\n"
      printf "  3. Verify connection with '%s devices'\n" "${ACTIVE_FASTBOOT_BIN}"
      return 1
    fi

    if [[ "${count}" -gt 1 ]]; then
      ui_fail "Multiple Fastboot devices detected. Pass --device <id> to specify."
      "${ACTIVE_FASTBOOT_BIN}" devices
      return 1
    fi

    TARGET_DEVICE_ID="${first_device}"
  fi

  if ! query_fastboot_device_list | grep -Fxq "${TARGET_DEVICE_ID}"; then
    ui_fail "Device '${TARGET_DEVICE_ID}' not visible to Fastboot."
    return 1
  fi

  ui_ok "Connected device: ${TARGET_DEVICE_ID}"
  return 0
}

function run_fastboot_on_device {
  "${ACTIVE_FASTBOOT_BIN}" -s "${TARGET_DEVICE_ID}" "$@" 2>&1 | tr -d '\r'
}

function format_profile_label {
  local profile=$1
  case "${profile}" in
    flashing-unlock) printf "fastboot flashing unlock" ;;
    flashing-unlock-code) printf "fastboot flashing unlock <code>" ;;
    oem-unlock-code) printf "fastboot oem unlock <code>" ;;
    oem-unlock) printf "fastboot oem unlock" ;;
    oem-unlock-go) printf "fastboot oem unlock-go" ;;
    *) printf "unknown" ;;
  esac
}

function profile_requires_code_generation {
  local profile=$1
  case "${profile}" in
    flashing-unlock|oem-unlock|oem-unlock-go) return 1 ;;
    *) return 0 ;;
  esac
}

function autodetect_unlock_command_profile {
  local requested_profile=$1 ability_output unlock_data_output product_output

  case "${requested_profile}" in
    flashing-unlock|flashing-unlock-code|oem-unlock-code|oem-unlock|oem-unlock-go)
      STATE_RESOLVED_COMMAND="${requested_profile}"
      ui_ok "Command profile: $(format_profile_label "${requested_profile}") (manual)"
      return 0
      ;;
    auto|"") ;;
    *)
      ui_fail "Invalid command profile: ${requested_profile}"
      return 1
      ;;
  esac

  render_section "PROFILE" "autodetecting safe fastboot unlock flow"

  ability_output=$(run_fastboot_on_device flashing get_unlock_ability || true)
  if printf "%s\n" "${ability_output}" | grep -Eq '(^|[^0-9])1([^0-9]|$)'; then
    STATE_RESOLVED_COMMAND="flashing-unlock"
    ui_ok "AOSP unlock ability confirmed (=1). Selected: $(format_profile_label "${STATE_RESOLVED_COMMAND}")"
    return 0
  fi

  unlock_data_output=$(run_fastboot_on_device oem get_unlock_data || true)
  if printf "%s\n" "${unlock_data_output}" | grep -Eiq 'unlock data|bootloader|INFO|Motorola|token'; then
    if ! printf "%s\n" "${unlock_data_output}" | grep -Eiq 'unknown command|not supported|FAILED|remote failure'; then
      STATE_RESOLVED_COMMAND="oem-unlock-code"
      ui_ok "OEM unlock-data flow responded. Selected: $(format_profile_label "${STATE_RESOLVED_COMMAND}")"
      return 0
    fi
  fi

  product_output=$(run_fastboot_on_device getvar product || true)
  if printf "%s\n" "${product_output}" | grep -Eiq 'pixel|google'; then
    STATE_RESOLVED_COMMAND="flashing-unlock"
    ui_ok "Google/Pixel target detected. Selected: $(format_profile_label "${STATE_RESOLVED_COMMAND}")"
    return 0
  fi

  STATE_RESOLVED_COMMAND="oem-unlock-code"
  ui_warn "No-code AOSP flow unconfirmed. Selected conservative code flow: $(format_profile_label "${STATE_RESOLVED_COMMAND}")"
  return 0
}

function dispatch_unlock_payload {
  local candidate_code=$1
  case "${STATE_RESOLVED_COMMAND}" in
    flashing-unlock) run_fastboot_on_device flashing unlock ;;
    flashing-unlock-code) run_fastboot_on_device flashing unlock "${candidate_code}" ;;
    oem-unlock-code) run_fastboot_on_device oem unlock "${candidate_code}" ;;
    oem-unlock) run_fastboot_on_device oem unlock ;;
    oem-unlock-go) run_fastboot_on_device oem unlock-go ;;
    *)
      printf "Invalid command profile: %s\n" "${STATE_RESOLVED_COMMAND}"
      return 2
      ;;
  esac
}

function is_terminal_fastboot_rejection {
  local raw_output=$1
  printf "%s\n" "${raw_output}" | grep -Eiq 'unknown command|not supported|not allowed|unlock ability is 0|unlock_ability.*0|oem unlock is not allowed|flashing unlock is not allowed|permission denied|device is locked by carrier|carrier|frp|not unlockable'
}

function is_fastboot_attempt_failure {
  local raw_output=$1
  printf "%s\n" "${raw_output}" | grep -Eiq 'fail|failed|failure|error|invalid|denied|wrong|incorrect|not match|mismatch|remote:'
}
