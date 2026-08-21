#!/usr/bin/env bash
# ==============================================================================
# test_pattern_engine.sh - Unit tests for pattern_engine.sh
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../test_helper.sh"

function test_mask_expansion {
  source "${LIB_DIR}/constants.sh"
  source "${LIB_DIR}/pattern_engine.sh"

  assert_eq "XXX" "$(expand_pattern_mask "X{3}")" "X{3} expansion"
  assert_eq "AAAA9AA" "$(expand_pattern_mask "A{4}9A{2}")" "A{4}9A{2} expansion"
  assert_eq "XXXX-XXXX" "$(expand_pattern_mask "XXXX-XXXX")" "Preserves literal hyphen"
  assert_eq "0123456789" "$(expand_pattern_mask "0123456789")" "Preserves literal digits"
}

function test_mask_validation {
  source "${LIB_DIR}/constants.sh"
  source "${LIB_DIR}/pattern_engine.sh"

  # Valid patterns
  validate_pattern_mask "X{20}" && status=0 || status=1
  assert_eq 0 "${status}" "X{20} is valid"

  validate_pattern_mask "A{4}9A{15}" && status=0 || status=1
  assert_eq 0 "${status}" "A{4}9A{15} is valid"

  validate_pattern_mask "9{6}" && status=0 || status=1
  assert_eq 0 "${status}" "9{6} is valid"

  # Invalid patterns
  validate_pattern_mask "" && status=0 || status=1
  assert_eq 1 "${status}" "Empty mask is invalid"

  validate_pattern_mask "X{20" && status=0 || status=1
  assert_eq 1 "${status}" "Unterminated brace is invalid"

  validate_pattern_mask "X{0}" && status=0 || status=1
  assert_eq 1 "${status}" "Zero count is invalid"

  validate_pattern_mask "X{abc}" && status=0 || status=1
  assert_eq 1 "${status}" "Non-numeric count is invalid"

  validate_pattern_mask "{5}" && status=0 || status=1
  assert_eq 1 "${status}" "Leading brace is invalid"
}

function test_charset_lookup {
  source "${LIB_DIR}/constants.sh"
  source "${LIB_DIR}/pattern_engine.sh"

  assert_eq "${CHARSET_DIGITS}" "$(get_charset_for_symbol "9" "")" "Token 9 -> digits"
  assert_eq "${CHARSET_UPPER_ALPHA}" "$(get_charset_for_symbol "A" "")" "Token A -> upper alpha"
  assert_eq "${CHARSET_LOWER_ALPHA}" "$(get_charset_for_symbol "a" "")" "Token a -> lower alpha"
  assert_eq "${CHARSET_UPPER_ALPHANUMERIC}" "$(get_charset_for_symbol "X" "")" "Token X -> upper alphanumeric"
  assert_eq "${CHARSET_MIXED_ALPHANUMERIC}" "$(get_charset_for_symbol "x" "")" "Token x -> mixed alphanumeric"
  assert_eq "${CHARSET_HEX_UPPER}" "$(get_charset_for_symbol "H" "")" "Token H -> hex upper"
  assert_eq "${CHARSET_HEX_LOWER}" "$(get_charset_for_symbol "h" "")" "Token h -> hex lower"
  assert_eq "CUSTOM123" "$(get_charset_for_symbol "?" "CUSTOM123")" "Token ? -> active charset"
  assert_eq "-" "$(get_charset_for_symbol "-" "")" "Literal char -> self"
}

function test_pattern_space_calculation {
  source "${LIB_DIR}/constants.sh"
  source "${LIB_DIR}/pattern_engine.sh"

  assert_eq "10" "$(calculate_pattern_space "9{1}" "")" "Space for 9{1}"
  assert_eq "1000" "$(calculate_pattern_space "9{3}" "")" "Space for 9{3}"
  assert_eq "676" "$(calculate_pattern_space "A{2}" "")" "Space for A{2}"
  assert_eq "256" "$(calculate_pattern_space "H{2}" "")" "Space for H{2}"
  assert_eq "1296" "$(calculate_pattern_space "X{2}" "")" "Space for X{2}"
  assert_eq "676" "$(calculate_pattern_space "A-A" "")" "Space with literal delimiter"
  assert_eq "huge" "$(calculate_pattern_space "X{20}" "")" "Space overflow -> huge"
}

function test_deterministic_code_generation {
  source "${LIB_DIR}/constants.sh"
  source "${LIB_DIR}/pattern_engine.sh"

  # Offset 0 with 9{3} -> 000
  assert_eq "000" "$(generate_code_from_offset 0 "9{3}" "")" "Offset 0 for 9{3}"
  assert_eq "001" "$(generate_code_from_offset 1 "9{3}" "")" "Offset 1 for 9{3}"
  assert_eq "010" "$(generate_code_from_offset 10 "9{3}" "")" "Offset 10 for 9{3}"
  assert_eq "999" "$(generate_code_from_offset 999 "9{3}" "")" "Offset 999 for 9{3}"

  # Offset 0 with A{2} -> AA, offset 25 -> AZ, offset 26 -> BA
  assert_eq "AA" "$(generate_code_from_offset 0 "A{2}" "")" "Offset 0 for A{2}"
  assert_eq "AZ" "$(generate_code_from_offset 25 "A{2}" "")" "Offset 25 for A{2}"
  assert_eq "BA" "$(generate_code_from_offset 26 "A{2}" "")" "Offset 26 for A{2}"
}

function test_weighted_pattern_schedule {
  source "${LIB_DIR}/constants.sh"
  source "${LIB_DIR}/pattern_engine.sh"

  local schedule="p1:9{3}:3:Profile 1;p2:A{2}:2:Profile 2;p3:H{2}:1:Profile 3"

  # Total weight: 3 + 2 + 1 = 6
  assert_eq "6" "$(calculate_pattern_weight_total "${schedule}")" "Total schedule weight"

  # Slot index selection
  assert_eq "0" "$(select_pattern_index_by_slot 0 "${schedule}")" "Slot 0 -> Index 0"
  assert_eq "0" "$(select_pattern_index_by_slot 2 "${schedule}")" "Slot 2 -> Index 0"
  assert_eq "1" "$(select_pattern_index_by_slot 3 "${schedule}")" "Slot 3 -> Index 1"
  assert_eq "1" "$(select_pattern_index_by_slot 4 "${schedule}")" "Slot 4 -> Index 1"
  assert_eq "2" "$(select_pattern_index_by_slot 5 "${schedule}")" "Slot 5 -> Index 2"

  # Weighted rotation with cursor wrapping
  assert_eq "0" "$(select_weighted_pattern_index 0 "${schedule}")" "Cursor 0 -> Index 0"
  assert_eq "0" "$(select_weighted_pattern_index 6 "${schedule}")" "Cursor 6 -> Index 0 (wrapped)"
  assert_eq "1" "$(select_weighted_pattern_index 3 "${schedule}")" "Cursor 3 -> Index 1"
}

run_test "Pattern DSL mask expansion" test_mask_expansion
run_test "Pattern DSL mask validation" test_mask_validation
run_test "Pattern DSL charset lookup" test_charset_lookup
run_test "Pattern DSL space calculation" test_pattern_space_calculation
run_test "Pattern DSL deterministic code generation" test_deterministic_code_generation
run_test "Pattern DSL weighted schedule selection" test_weighted_pattern_schedule

finish_tests
