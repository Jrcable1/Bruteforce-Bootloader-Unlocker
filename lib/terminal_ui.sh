#!/usr/bin/env bash
# ==============================================================================
# terminal_ui.sh - Terminal styling, visual hierarchy, and responsive UI
# ==============================================================================

[[ -n "${TERMINAL_UI_INCLUDED:-}" ]] && return 0
readonly TERMINAL_UI_INCLUDED=1

function terminal_stdout_is_tty {
  [[ -t 1 ]]
}

function init_terminal_styles {
  if ! terminal_stdout_is_tty || [[ -n "${NO_COLOR:-}" || "${TERM:-}" == "dumb" ]]; then
    STYLE_BOLD=""
    STYLE_DIM=""
    STYLE_RESET=""
    COLOR_RED=""
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_BLUE=""
    COLOR_MAGENTA=""
    COLOR_CYAN=""
    COLOR_WHITE=""
    return 0
  fi

  STYLE_BOLD="$(printf '\033[1m')"
  STYLE_DIM="$(printf '\033[2m')"
  STYLE_RESET="$(printf '\033[0m')"
  COLOR_RED="$(printf '\033[31m')"
  COLOR_GREEN="$(printf '\033[32m')"
  COLOR_YELLOW="$(printf '\033[33m')"
  COLOR_BLUE="$(printf '\033[34m')"
  COLOR_MAGENTA="$(printf '\033[35m')"
  COLOR_CYAN="$(printf '\033[36m')"
  COLOR_WHITE="$(printf '\033[37m')"
}

init_terminal_styles

function get_terminal_width {
  local cols
  if terminal_stdout_is_tty && command -v tput >/dev/null 2>&1; then
    cols=$(tput cols 2>/dev/null)
    if [[ "${cols}" =~ ^[0-9]+$ && "${cols}" -ge 40 ]]; then
      printf "%s" "${cols}"
      return 0
    fi
  fi
  printf "%s" "${COLUMNS:-80}"
}

function render_banner {
  local width count line="" i
  width=$(get_terminal_width)
  count=$(( width > 64 ? 64 : width ))
  for (( i=0; i<count; i++ )); do
    line="${line}─"
  done

  printf "%s%sFASTBOOT UNLOCK CONSOLE%s\n" "${COLOR_CYAN}" "${STYLE_BOLD}" "${STYLE_RESET}"
  printf "%s%sscope: authorized devices only | transport: fastboot | mode: pattern search%s\n" "${STYLE_DIM}" "${COLOR_WHITE}" "${STYLE_RESET}"
  printf "%s%s%s\n" "${STYLE_DIM}" "${line}" "${STYLE_RESET}"
}

function render_section {
  local tag=$1 title=$2
  printf "\n%s%s[%s]%s %s%s%s\n" "${COLOR_CYAN}" "${STYLE_BOLD}" "${tag}" "${STYLE_RESET}" "${STYLE_BOLD}" "${title}" "${STYLE_RESET}"
}

function ui_ok {
  local message=$1
  printf "%s[OK]%s %s\n" "${COLOR_GREEN}" "${STYLE_RESET}" "${message}"
}

function ui_warn {
  local message=$1
  printf "%s[WARN]%s %s\n" "${COLOR_YELLOW}" "${STYLE_RESET}" "${message}"
}

function ui_fail {
  local message=$1
  printf "%s[ERR]%s %s\n" "${COLOR_RED}" "${STYLE_RESET}" "${message}"
}

function ui_info {
  local message=$1
  printf "%s[INFO]%s %s\n" "${COLOR_CYAN}" "${STYLE_RESET}" "${message}"
}

function render_progress_line {
  local raw_text=$1 term_width max_len
  term_width=$(get_terminal_width)
  max_len=$(( term_width - 1 ))

  if (( ${#raw_text} > max_len )); then
    raw_text="${raw_text:0:$(( max_len - 3 ))}..."
  fi

  printf "\r\033[K%s" "${raw_text}"
}
