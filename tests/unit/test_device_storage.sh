#!/usr/bin/env bash
# ==============================================================================
# test_device_storage.sh - Unit tests for device_storage.sh
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../test_helper.sh"

function test_sanitization {
  source "${LIB_DIR}/device_storage.sh"

  assert_eq "ZY22345678" "$(sanitize_device_identifier "ZY22345678")" "Normal alphanumeric ID"
  assert_eq "device_123.45-6" "$(sanitize_device_identifier "device 123.45-6")" "Spaces converted to underscore"
  assert_eq ".._.._device" "$(sanitize_device_identifier "../../device")" "Path traversal slashes neutralized"
  assert_eq "a_b_c_d" "$(sanitize_device_identifier "a/b:c\d")" "Slashes and colons neutralized"
  assert_eq "" "$(sanitize_device_identifier "")" "Empty ID remains empty"
}

function test_path_resolution {
  source "${LIB_DIR}/device_storage.sh"

  assert_eq "./ZY22345678.dat" "$(resolve_state_file_path "ZY22345678")" "State file path"
  assert_eq "./SUCCESS_ZY22345678.txt" "$(resolve_success_file_path "ZY22345678")" "Success file path"
}

function test_state_loading {
  source "${LIB_DIR}/device_storage.sh"

  cat <<'EOF' > state_test.dat
code_type=numeric
code_length=8
last_value=4500
charset=0123456789
strategy=smart
known_positions=0:1;4:9
command_profile=oem-unlock-code
patterns=custom:9{8}:10:Numeric 8-digit
pattern_offsets=4500,0,0
resolved_command=oem-unlock-code
EOF

  load_device_state "state_test.dat"

  assert_eq "numeric" "${STORED_CODE_TYPE}" "STORED_CODE_TYPE loaded"
  assert_eq "8" "${STORED_CODE_LENGTH}" "STORED_CODE_LENGTH loaded"
  assert_eq "4500" "${STORED_LAST_VALUE}" "STORED_LAST_VALUE loaded"
  assert_eq "0123456789" "${STORED_CHARSET}" "STORED_CHARSET loaded"
  assert_eq "smart" "${STORED_STRATEGY}" "STORED_STRATEGY loaded"
  assert_eq "0:1;4:9" "${STORED_KNOWN_POSITIONS}" "STORED_KNOWN_POSITIONS loaded"
  assert_eq "oem-unlock-code" "${STORED_COMMAND_PROFILE}" "STORED_COMMAND_PROFILE loaded"
  assert_eq "custom:9{8}:10:Numeric 8-digit" "${STORED_PATTERNS}" "STORED_PATTERNS loaded"
  assert_eq "4500,0,0" "${STORED_PATTERN_OFFSETS}" "STORED_PATTERN_OFFSETS loaded"
  assert_eq "oem-unlock-code" "${STORED_RESOLVED_COMMAND}" "STORED_RESOLVED_COMMAND loaded"
}

function test_atomic_state_save {
  source "${LIB_DIR}/device_storage.sh"

  CONFIG_CODE_TYPE="moto"
  CONFIG_CODE_LENGTH="20"
  STATE_GLOBAL_CURSOR="1200"
  CONFIG_ACTIVE_CHARSET="0123456789ABCDEF"
  CONFIG_STRATEGY="sequential"
  CONFIG_KNOWN_POSITIONS=""
  CONFIG_COMMAND_PROFILE="auto"
  CONFIG_PATTERNS="motorola-portal-20:X{20}:10:Portal key"
  STATE_PATTERN_OFFSETS="1200"
  STATE_RESOLVED_COMMAND="oem-unlock-code"

  save_device_state "device_state.dat"
  assert_file_exists "device_state.dat" "Persisted state file must exist"

  # Verify content
  local content
  content=$(cat "device_state.dat")
  assert_contains "${content}" "code_type=moto" "Contains code_type"
  assert_contains "${content}" "last_value=1200" "Contains last_value"
  assert_contains "${content}" "resolved_command=oem-unlock-code" "Contains resolved_command"

  # Verify no dangling tmp files
  local tmp_count
  tmp_count=$(ls -1 device_state.dat.tmp.* 2>/dev/null | wc -l || true)
  assert_eq 0 "${tmp_count}" "No temporary files must remain after save"
}

function test_record_success {
  source "${LIB_DIR}/device_storage.sh"

  record_successful_unlock "SUCCESS_DEVICE.txt" "SECRETKEY12345"
  assert_file_exists "SUCCESS_DEVICE.txt" "Success file must exist"

  local content
  content=$(cat "SUCCESS_DEVICE.txt")
  assert_eq "SECRETKEY12345" "${content}" "Exact unlock code must be recorded"
}

function test_apply_known_positions {
  source "${LIB_DIR}/device_storage.sh"

  local original="0000000000"
  local modified

  # Position 0 -> 9, Position 5 -> A
  modified=$(apply_known_positional_characters "${original}" "0:9;5:A")
  assert_eq "90000A0000" "${modified}" "Substitutions applied correctly"

  # Out of range and invalid formats ignored
  modified=$(apply_known_positional_characters "${original}" "99:Z;abc:X;-1:Y;2:")
  assert_eq "0000000000" "${modified}" "Invalid specifications ignored"

  # Empty specification returns original
  assert_eq "${original}" "$(apply_known_positional_characters "${original}" "")" "Empty spec returns original"
}

run_test "Storage device ID sanitization" test_sanitization
run_test "Storage file path resolution" test_path_resolution
run_test "Storage state file loading" test_state_loading
run_test "Storage atomic state save" test_atomic_state_save
run_test "Storage record successful unlock" test_record_success
run_test "Storage apply known positions" test_apply_known_positions

finish_tests
