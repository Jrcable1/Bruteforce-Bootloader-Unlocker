#!/usr/bin/env bash
# ==============================================================================
# test_terminal_ui.sh - Unit tests for terminal_ui.sh
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../test_helper.sh"

function test_style_initialization_tty {
  source "${LIB_DIR}/terminal_ui.sh"
  function terminal_stdout_is_tty { return 0; }
  unset NO_COLOR
  TERM="xterm-256color"
  init_terminal_styles

  assert_not_eq "" "${COLOR_CYAN}" "COLOR_CYAN must be set when TTY is available"
  assert_not_eq "" "${COLOR_GREEN}" "COLOR_GREEN must be set when TTY is available"
  assert_not_eq "" "${STYLE_BOLD}" "STYLE_BOLD must be set when TTY is available"
}

function test_style_initialization_no_color {
  source "${LIB_DIR}/terminal_ui.sh"
  function terminal_stdout_is_tty { return 0; }
  export NO_COLOR=1
  init_terminal_styles

  assert_eq "" "${COLOR_CYAN}" "COLOR_CYAN must be empty with NO_COLOR"
  assert_eq "" "${COLOR_GREEN}" "COLOR_GREEN must be empty with NO_COLOR"
  assert_eq "" "${STYLE_BOLD}" "STYLE_BOLD must be empty with NO_COLOR"
}

function test_style_initialization_dumb_term {
  source "${LIB_DIR}/terminal_ui.sh"
  function terminal_stdout_is_tty { return 0; }
  unset NO_COLOR
  export TERM="dumb"
  init_terminal_styles

  assert_eq "" "${COLOR_CYAN}" "COLOR_CYAN must be empty on TERM=dumb"
  assert_eq "" "${COLOR_RED}" "COLOR_RED must be empty on TERM=dumb"
  assert_eq "" "${STYLE_RESET}" "STYLE_RESET must be empty on TERM=dumb"
}

function test_terminal_width_detection {
  source "${LIB_DIR}/terminal_ui.sh"

  # Case 1: TTY with valid tput cols
  function terminal_stdout_is_tty { return 0; }
  function tput { printf "120"; }
  assert_eq "120" "$(get_terminal_width)" "Width should come from tput cols"

  # Case 2: tput returns width < 40, fallback to COLUMNS
  function tput { printf "20"; }
  COLUMNS=90
  assert_eq "90" "$(get_terminal_width)" "Width < 40 should fallback to COLUMNS"

  # Case 3: non-TTY, fallback to default 80
  function terminal_stdout_is_tty { return 1; }
  unset COLUMNS
  assert_eq "80" "$(get_terminal_width)" "Non-TTY should fallback to default 80"
}

function test_rendering_banner {
  source "${LIB_DIR}/terminal_ui.sh"
  function terminal_stdout_is_tty { return 1; }
  init_terminal_styles

  local banner
  banner=$(render_banner)
  assert_contains "${banner}" "FASTBOOT UNLOCK CONSOLE" "Banner must contain title"
  assert_contains "${banner}" "scope: authorized devices only" "Banner must contain scope"
  assert_no_ansi "${banner}" "Banner in non-TTY must not contain ANSI"
}

function test_rendering_sections_and_badges {
  source "${LIB_DIR}/terminal_ui.sh"
  function terminal_stdout_is_tty { return 1; }
  init_terminal_styles

  local out_sec out_ok out_warn out_fail out_info
  out_sec=$(render_section "PLAN" "runtime execution profile")
  out_ok=$(ui_ok "Device ready")
  out_warn=$(ui_warn "Fallback used")
  out_fail=$(ui_fail "Process aborted")
  out_info=$(ui_info "State saved")

  assert_contains "${out_sec}" "[PLAN] runtime execution profile" "Section format"
  assert_contains "${out_ok}" "[OK] Device ready" "ui_ok format"
  assert_contains "${out_warn}" "[WARN] Fallback used" "ui_warn format"
  assert_contains "${out_fail}" "[ERR] Process aborted" "ui_fail format"
  assert_contains "${out_info}" "[INFO] State saved" "ui_info format"

  assert_no_ansi "${out_sec}" "Section without color has no ANSI"
  assert_no_ansi "${out_ok}" "ui_ok without color has no ANSI"
}

function test_progress_line_truncation {
  source "${LIB_DIR}/terminal_ui.sh"
  function terminal_stdout_is_tty { return 1; }
  COLUMNS=50

  local long_text="Trying: A3F9B2C1D4E5F6G7H8J9 | #1420 | motorola-portal-20 (X{20}) | Progress: 0.001%"
  local rendered
  rendered=$(render_progress_line "${long_text}")

  assert_contains "${rendered}" "..." "Long progress line must truncate with ellipsis"
  # Truncated length without control chars should fit terminal width
  local stripped="${rendered//$'\r\033[K'/}"
  assert_eq 49 "${#stripped}" "Stripped progress line length must match max width limit"
}

run_test "Terminal UI styles on TTY" test_style_initialization_tty
run_test "Terminal UI styles with NO_COLOR" test_style_initialization_no_color
run_test "Terminal UI styles on TERM=dumb" test_style_initialization_dumb_term
run_test "Terminal UI width geometry detection" test_terminal_width_detection
run_test "Terminal UI banner rendering" test_rendering_banner
run_test "Terminal UI sections and badges" test_rendering_sections_and_badges
run_test "Terminal UI progress line truncation" test_progress_line_truncation

finish_tests
