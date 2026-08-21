#!/usr/bin/env bash
# ==============================================================================
# test_fastboot_client.sh - Unit tests for fastboot_client.sh
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../test_helper.sh"

function test_binary_discovery {
  source "${LIB_DIR}/terminal_ui.sh"
  source "${LIB_DIR}/fastboot_client.sh"
  function terminal_stdout_is_tty { return 1; }
  init_terminal_styles

  # Mock custom fastboot
  create_mock_fastboot
  local found_bin
  found_bin=$(find_fastboot_binary)
  assert_not_eq "" "${found_bin}" "Found mock fastboot binary"

  # Verify host dependencies
  verify_host_dependencies && status=0 || status=1
  assert_eq 0 "${status}" "verify_host_dependencies succeeds with mock binary"
}

function test_device_resolution {
  source "${LIB_DIR}/terminal_ui.sh"
  source "${LIB_DIR}/fastboot_client.sh"
  function terminal_stdout_is_tty { return 1; }
  init_terminal_styles
  create_mock_fastboot
  ACTIVE_FASTBOOT_BIN="${FASTBOOT_BIN}"

  # Single device detected
  export MOCK_FASTBOOT_DEVICES="ZY22345678	fastboot"
  resolve_target_device "" && status=0 || status=1
  assert_eq 0 "${status}" "Resolve single connected device"
  assert_eq "ZY22345678" "${TARGET_DEVICE_ID}" "TARGET_DEVICE_ID set correctly"

  # Zero devices detected -> fails
  export MOCK_FASTBOOT_DEVICES=""
  resolve_target_device "" && status=0 || status=1
  assert_eq 1 "${status}" "Zero devices must fail"

  # Multiple devices without override -> fails
  export MOCK_FASTBOOT_DEVICES=$(printf "DEV1\tfastboot\nDEV2\tfastboot")
  resolve_target_device "" && status=0 || status=1
  assert_eq 1 "${status}" "Multiple devices without override must fail"

  # Multiple devices with override -> succeeds
  resolve_target_device "DEV2" && status=0 || status=1
  assert_eq 0 "${status}" "Multiple devices with valid override succeeds"
  assert_eq "DEV2" "${TARGET_DEVICE_ID}" "TARGET_DEVICE_ID matches override"
}

function test_profile_labels_and_requirements {
  source "${LIB_DIR}/fastboot_client.sh"

  assert_eq "fastboot flashing unlock" "$(format_profile_label "flashing-unlock")" "flashing-unlock label"
  assert_eq "fastboot oem unlock <code>" "$(format_profile_label "oem-unlock-code")" "oem-unlock-code label"

  # Requires code: returns 0 (success in bash) for code-bearing, 1 for direct
  profile_requires_code_generation "oem-unlock-code" && req_code=1 || req_code=0
  assert_eq 1 "${req_code}" "oem-unlock-code requires code"

  profile_requires_code_generation "flashing-unlock" && req_direct=1 || req_direct=0
  assert_eq 0 "${req_direct}" "flashing-unlock does not require code"
}

function test_profile_autodetection {
  source "${LIB_DIR}/terminal_ui.sh"
  source "${LIB_DIR}/fastboot_client.sh"
  function terminal_stdout_is_tty { return 1; }
  init_terminal_styles
  create_mock_fastboot
  ACTIVE_FASTBOOT_BIN="${FASTBOOT_BIN}"
  TARGET_DEVICE_ID="TESTDEV001"

  # Case 1: Ability = 1 -> flashing-unlock
  export MOCK_FASTBOOT_UNLOCK_ABILITY="1"
  export MOCK_FASTBOOT_UNLOCK_DATA=""
  autodetect_unlock_command_profile "auto"
  assert_eq "flashing-unlock" "${STATE_RESOLVED_COMMAND}" "Autodetect flashing-unlock via ability=1"

  # Case 2: Ability = 0, OEM data present -> oem-unlock-code
  export MOCK_FASTBOOT_UNLOCK_ABILITY="0"
  export MOCK_FASTBOOT_UNLOCK_DATA="(bootloader) 3A99240409204245#41323838383838"
  autodetect_unlock_command_profile "auto"
  assert_eq "oem-unlock-code" "${STATE_RESOLVED_COMMAND}" "Autodetect oem-unlock-code via unlock_data"

  # Case 3: Manual override preserves requested profile
  autodetect_unlock_command_profile "oem-unlock-go"
  assert_eq "oem-unlock-go" "${STATE_RESOLVED_COMMAND}" "Manual override preserved"
}

function test_error_classifications {
  source "${LIB_DIR}/fastboot_client.sh"

  # Terminal error detections
  local term1="FAILED (remote: device is locked by carrier)"
  local term2="FAILED (remote: flashing unlock is not allowed by FRP)"
  local term3="FAILED (remote: unknown command)"
  local term4="FAILED (remote: oem unlock is not allowed)"

  is_terminal_fastboot_rejection "${term1}" && t1=1 || t1=0
  is_terminal_fastboot_rejection "${term2}" && t2=1 || t2=0
  is_terminal_fastboot_rejection "${term3}" && t3=1 || t3=0
  is_terminal_fastboot_rejection "${term4}" && t4=1 || t4=0

  assert_eq 1 "${t1}" "Detect carrier lock"
  assert_eq 1 "${t2}" "Detect FRP lock"
  assert_eq 1 "${t3}" "Detect unknown command"
  assert_eq 1 "${t4}" "Detect OEM unlock not allowed"

  # Retryable failure detections
  local fail1="FAILED (remote: Check password failed!)"
  local fail2="FAILED (remote: invalid code)"
  local okay="OKAY [ 0.500s]"

  is_fastboot_attempt_failure "${fail1}" && f1=1 || f1=0
  is_fastboot_attempt_failure "${fail2}" && f2=1 || f2=0
  is_fastboot_attempt_failure "${okay}" && f3=1 || f3=0

  assert_eq 1 "${f1}" "Detect password check failure"
  assert_eq 1 "${f2}" "Detect invalid code"
  assert_eq 0 "${f3}" "OKAY is not a failure"
}

run_test "Fastboot binary discovery and host dependencies" test_binary_discovery
run_test "Fastboot device list and target resolution" test_device_resolution
run_test "Fastboot profile labels and requirements" test_profile_labels_and_requirements
run_test "Fastboot profile autodetection" test_profile_autodetection
run_test "Fastboot error classifications" test_error_classifications

finish_tests
