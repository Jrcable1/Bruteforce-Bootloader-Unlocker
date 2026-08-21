#!/usr/bin/env bash
# ==============================================================================
# unlock_runner.sh - Execution engine, authorization guard, and progress tracker
# ==============================================================================

[[ -n "${UNLOCK_RUNNER_INCLUDED:-}" ]] && return 0
readonly UNLOCK_RUNNER_INCLUDED=1

function format_percentage_string {
  local current=$1 total=$2 whole frac
  if [[ "${total}" == "huge" || ! "${total}" =~ ^[0-9]+$ || "${total}" -le 0 ]]; then
    printf "n/a"
    return 0
  fi
  whole=$(( current * 100 / total ))
  frac=$(( (current * 100 % total) * 1000 / total ))
  printf "%d.%03d" "${whole}" "${frac}"
}

function format_time_estimate {
  local current=$1 total=$2 elapsed=$3 rate remaining days hours minutes seconds

  if [[ "${total}" == "huge" || ! "${total}" =~ ^[0-9]+$ || ${current} -le 0 || ${elapsed} -le 0 ]]; then
    printf "calculating"
    return 0
  fi

  rate=$(( current / elapsed ))
  if [[ ${rate} -le 0 ]]; then
    printf "calculating"
    return 0
  fi

  if (( current >= total )); then
    printf "0s"
    return 0
  fi

  remaining=$(( (total - current) / rate ))
  days=$(( remaining / 86400 ))
  hours=$(( (remaining % 86400) / 3600 ))
  minutes=$(( (remaining % 3600) / 60 ))
  seconds=$(( remaining % 60 ))

  if [[ ${days} -gt 0 ]]; then
    printf "%dd %dh %dm" "${days}" "${hours}" "${minutes}"
  elif [[ ${hours} -gt 0 ]]; then
    printf "%dh %dm %ds" "${hours}" "${minutes}" "${seconds}"
  elif [[ ${minutes} -gt 0 ]]; then
    printf "%dm %ds" "${minutes}" "${seconds}"
  else
    printf "%ds" "${seconds}"
  fi
}

function prompt_authorization_guard {
  render_section "RULE" "authorized use confirmation"
  printf "This tool sends bootloader unlock commands to the connected device.\n"
  printf "Use only on devices you own or are legally authorized to service.\n"
  printf "Unlocking will wipe all user data and may void manufacturer warranty.\n\n"

  local confirmation_input=""
  read -r -p "Type AUTHORIZED to proceed: " confirmation_input
  if [[ "${confirmation_input}" != "AUTHORIZED" ]]; then
    ui_fail "Authorization confirmation was not provided. Aborting."
    exit "${EXIT_GENERAL_ERROR}"
  fi
}

function display_runtime_summary {
  render_section "PLAN" "runtime execution profile"
  printf "  Device ID:        %s\n" "${TARGET_DEVICE_ID}"
  printf "  State File:       %s\n" "${TARGET_STATE_FILE}"
  printf "  Command Flow:     %s\n" "$(format_profile_label "${STATE_RESOLVED_COMMAND}")"
  printf "  Strategy:         %s\n" "${CONFIG_STRATEGY}"

  if ! profile_requires_code_generation "${STATE_RESOLVED_COMMAND}"; then
    ui_warn "Profile runs a direct unlock command without codes (device may prompt on screen)."
    return 0
  fi

  printf "  Code Charset:     %s\n" "${CONFIG_CODE_TYPE}"
  if [[ -n "${CONFIG_PATTERNS}" ]]; then
    printf "  Pattern Schedule: weighted priority DSL\n"
    IFS=';' read -ra entries <<< "${CONFIG_PATTERNS}"
    for entry in "${entries[@]}"; do
      IFS=':' read -r name mask weight desc <<< "${entry}"
      printf "    - %-20s mask=%-12s weight=%-3s space=%s\n" "${name}" "${mask}" "${weight}" "$(calculate_pattern_space "${mask}" "${CONFIG_ACTIVE_CHARSET}")"
    done
  fi
}

function execute_direct_command_flow {
  render_section "RUN" "dispatching direct unlock command"
  local output status
  set +e
  output=$(dispatch_unlock_payload "")
  status=$?
  set -e

  printf "%s\n" "${output}"
  if [[ ${status} -eq 0 ]] && ! is_fastboot_attempt_failure "${output}"; then
    ui_ok "Unlock command sent successfully. Confirm on device display if prompted."
    exit "${EXIT_SUCCESS}"
  fi

  ui_fail "Unlock command was rejected by the device."
  exit "${EXIT_GENERAL_ERROR}"
}

function fetch_next_candidate_code {
  local selected_idx entry name mask weight desc offset space code

  if [[ -z "${CONFIG_PATTERNS}" ]]; then
    code=$(generate_code_from_offset "${STATE_GLOBAL_CURSOR}" "X{${CONFIG_CODE_LENGTH}}" "${CONFIG_ACTIVE_CHARSET}")
    CURRENT_PATTERN_NAME="generic"
    CURRENT_PATTERN_MASK="X{${CONFIG_CODE_LENGTH}}"
    CURRENT_PATTERN_SPACE=$(calculate_pattern_space "X{${CONFIG_CODE_LENGTH}}" "${CONFIG_ACTIVE_CHARSET}")
    CURRENT_PATTERN_OFFSET="${STATE_GLOBAL_CURSOR}"
    CURRENT_CANDIDATE_CODE=$(apply_known_positional_characters "${code}" "${CONFIG_KNOWN_POSITIONS}")
    return 0
  fi

  case "${CONFIG_STRATEGY}" in
    random) selected_idx=$(select_random_pattern_index "${CONFIG_PATTERNS}") ;;
    sequential) selected_idx=0 ;;
    *) selected_idx=$(select_weighted_pattern_index "${STATE_GLOBAL_CURSOR}" "${CONFIG_PATTERNS}") ;;
  esac

  IFS=';' read -ra entries <<< "${CONFIG_PATTERNS}"
  entry="${entries[$selected_idx]}"
  IFS=':' read -r name mask weight desc <<< "${entry}"

  IFS=',' read -ra offsets_arr <<< "${STATE_PATTERN_OFFSETS}"
  offset="${offsets_arr[$selected_idx]:-0}"
  space=$(calculate_pattern_space "${mask}" "${CONFIG_ACTIVE_CHARSET}")

  if [[ "${CONFIG_STRATEGY}" == "random" ]]; then
    code=$(generate_random_pattern_code "${mask}" "${CONFIG_ACTIVE_CHARSET}")
  else
    if [[ "${space}" != "huge" && "${space}" -gt 0 && "${offset}" -ge "${space}" ]]; then
      offset=0
      offsets_arr[$selected_idx]=0
    fi
    code=$(generate_code_from_offset "${offset}" "${mask}" "${CONFIG_ACTIVE_CHARSET}")
  fi

  CURRENT_PATTERN_INDEX="${selected_idx}"
  CURRENT_PATTERN_NAME="${name}"
  CURRENT_PATTERN_MASK="${mask}"
  CURRENT_PATTERN_SPACE="${space}"
  CURRENT_PATTERN_OFFSET="${offset}"

  CURRENT_CANDIDATE_CODE=$(apply_known_positional_characters "${code}" "${CONFIG_KNOWN_POSITIONS}")
}

function advance_runtime_cursor {
  STATE_GLOBAL_CURSOR=$(( STATE_GLOBAL_CURSOR + 1 ))
  [[ -z "${CURRENT_PATTERN_INDEX:-}" ]] && return 0

  IFS=',' read -ra offsets_arr <<< "${STATE_PATTERN_OFFSETS}"
  offsets_arr[$CURRENT_PATTERN_INDEX]=$(( ${offsets_arr[$CURRENT_PATTERN_INDEX]:-0} + 1 ))

  local joined="" i
  for (( i=0; i<${#offsets_arr[@]}; i++ )); do
    [[ $i -gt 0 ]] && joined="${joined},"
    joined="${joined}${offsets_arr[$i]:-0}"
  done
  STATE_PATTERN_OFFSETS="${joined}"
}

function execute_candidate_search_loop {
  render_section "RUN" "starting unlock code evaluation"
  local start_time attempts=0 candidate_code output status elapsed pct time_left

  start_time=$(date +%s)

  while true; do
    fetch_next_candidate_code
    candidate_code="${CURRENT_CANDIDATE_CODE}"
    set +e
    output=$(dispatch_unlock_payload "${candidate_code}")
    status=$?
    set -e

    if is_terminal_fastboot_rejection "${output}"; then
      printf "\n"
      ui_fail "Terminal Fastboot error encountered (OEM lock disabled, carrier restriction, or unsupported command):"
      printf "%s\n" "${output}"
      save_device_state "${TARGET_STATE_FILE}"
      exit "${EXIT_TERMINAL_FASTBOOT_ERROR}"
    fi

    if [[ ${status} -eq 0 ]] && ! is_fastboot_attempt_failure "${output}"; then
      printf "\n\n"
      ui_ok "SUCCESS! Verified unlock code: ${candidate_code}"
      record_successful_unlock "${TARGET_SUCCESS_FILE}" "${candidate_code}"
      ui_ok "Recorded code to ${TARGET_SUCCESS_FILE}"
      save_device_state "${TARGET_STATE_FILE}"
      break
    fi

    attempts=$(( attempts + 1 ))
    advance_runtime_cursor

    if (( attempts % DEFAULT_UPDATE_INTERVAL == 0 )); then
      elapsed=$(( $(date +%s) - start_time ))
      pct=$(format_percentage_string "${CURRENT_PATTERN_OFFSET}" "${CURRENT_PATTERN_SPACE}")
      time_left=$(format_time_estimate "${CURRENT_PATTERN_OFFSET}" "${CURRENT_PATTERN_SPACE}" "${elapsed}")
      render_progress_line "Trying: ${candidate_code} | #${attempts} | ${CURRENT_PATTERN_NAME} (${CURRENT_PATTERN_MASK}) | Offset: ${CURRENT_PATTERN_OFFSET} | Progress: ${pct}% | Elapsed: ${elapsed}s | Est: ${time_left}"

      if (( attempts % DEFAULT_PERSIST_INTERVAL == 0 )); then
        save_device_state "${TARGET_STATE_FILE}"
      fi
    fi
  done
}
