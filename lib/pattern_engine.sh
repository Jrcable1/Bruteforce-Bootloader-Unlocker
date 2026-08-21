#!/usr/bin/env bash
# ==============================================================================
# pattern_engine.sh - Pattern DSL expansion, combinations, and code generation
# ==============================================================================

[[ -n "${PATTERN_ENGINE_INCLUDED:-}" ]] && return 0
readonly PATTERN_ENGINE_INCLUDED=1

function repeat_character {
  local char=$1 count=$2 output="" i
  for (( i=0; i<count; i++ )); do
    output="${output}${char}"
  done
  printf "%s" "${output}"
}

function expand_pattern_mask {
  local pattern=$1 output="" i=0 char count j num_str

  while (( i < ${#pattern} )); do
    char="${pattern:i:1}"
    count=1

    if [[ "${pattern:i+1:1}" == "{" ]]; then
      j=$(( i + 2 ))
      num_str=""
      while (( j < ${#pattern} )) && [[ "${pattern:j:1}" != "}" ]]; do
        num_str="${num_str}${pattern:j:1}"
        j=$(( j + 1 ))
      done
      if [[ "${pattern:j:1}" == "}" && "${num_str}" =~ ^[0-9]+$ && "${num_str}" -gt 0 ]]; then
        count="${num_str}"
        i="${j}"
      fi
    fi

    output="${output}$(repeat_character "${char}" "${count}")"
    i=$(( i + 1 ))
  done

  printf "%s" "${output}"
}

function get_charset_for_symbol {
  local symbol=$1 active_charset=$2
  case "${symbol}" in
    9) printf "%s" "${CHARSET_DIGITS}" ;;
    A) printf "%s" "${CHARSET_UPPER_ALPHA}" ;;
    a) printf "%s" "${CHARSET_LOWER_ALPHA}" ;;
    X) printf "%s" "${CHARSET_UPPER_ALPHANUMERIC}" ;;
    x) printf "%s" "${CHARSET_MIXED_ALPHANUMERIC}" ;;
    H) printf "%s" "${CHARSET_HEX_UPPER}" ;;
    h) printf "%s" "${CHARSET_HEX_LOWER}" ;;
    \?) printf "%s" "${active_charset}" ;;
    *) printf "%s" "${symbol}" ;;
  esac
}

function validate_pattern_mask {
  local mask=$1 i=0 char j num_str
  [[ -z "${mask}" ]] && return 1

  while (( i < ${#mask} )); do
    char="${mask:i:1}"
    if [[ "${char}" == "{" ]]; then
      return 1
    fi
    if [[ "${mask:i+1:1}" == "{" ]]; then
      j=$(( i + 2 ))
      num_str=""
      while (( j < ${#mask} )) && [[ "${mask:j:1}" != "}" ]]; do
        num_str="${num_str}${mask:j:1}"
        j=$(( j + 1 ))
      done
      if (( j >= ${#mask} )) || [[ "${mask:j:1}" != "}" ]]; then
        return 1
      fi
      if [[ ! "${num_str}" =~ ^[0-9]+$ || "${num_str}" -le 0 ]]; then
        return 1
      fi
      i="${j}"
    fi
    i=$(( i + 1 ))
  done

  return 0
}

function calculate_pattern_space {
  local mask=$1 active_charset=$2 expanded i symbol cs base total=1
  expanded=$(expand_pattern_mask "${mask}")

  for (( i=0; i<${#expanded}; i++ )); do
    symbol="${expanded:i:1}"
    cs=$(get_charset_for_symbol "${symbol}" "${active_charset}")
    base=${#cs}
    if (( total > MAX_INTEGER_VALUE / (base > 0 ? base : 1) )); then
      printf "huge"
      return 0
    fi
    total=$(( total * (base > 0 ? base : 1) ))
  done

  printf "%s" "${total}"
}

function generate_code_from_offset {
  local offset=$1 mask=$2 active_charset=$3 expanded result="" i symbol cs base idx ch
  expanded=$(expand_pattern_mask "${mask}")

  for (( i=${#expanded}-1; i>=0; i-- )); do
    symbol="${expanded:i:1}"
    cs=$(get_charset_for_symbol "${symbol}" "${active_charset}")
    base=${#cs}
    if (( base <= 1 )); then
      ch="${cs}"
    else
      idx=$(( offset % base ))
      ch="${cs:idx:1}"
      offset=$(( offset / base ))
    fi
    result="${ch}${result}"
  done

  printf "%s" "${result}"
}

function generate_random_pattern_code {
  local mask=$1 active_charset=$2 expanded result="" i symbol cs base idx ch
  expanded=$(expand_pattern_mask "${mask}")

  for (( i=0; i<${#expanded}; i++ )); do
    symbol="${expanded:i:1}"
    cs=$(get_charset_for_symbol "${symbol}" "${active_charset}")
    base=${#cs}
    if (( base <= 1 )); then
      ch="${cs}"
    else
      idx=$(( RANDOM % base ))
      ch="${cs:idx:1}"
    fi
    result="${result}${ch}"
  done

  printf "%s" "${result}"
}

function calculate_pattern_weight_total {
  local raw_patterns=$1 total=0 entry name mask weight desc
  IFS=';' read -ra entries <<< "${raw_patterns}"
  for entry in "${entries[@]}"; do
    IFS=':' read -r name mask weight desc <<< "${entry}"
    if [[ ! "${weight}" =~ ^[0-9]+$ || "${weight}" -le 0 ]]; then weight=1; fi
    total=$(( total + weight ))
  done
  printf "%s" "${total}"
}

function select_pattern_index_by_slot {
  local target_slot=$1 raw_patterns=$2 cumulative=0 i entry name mask weight desc
  IFS=';' read -ra entries <<< "${raw_patterns}"
  for (( i=0; i<${#entries[@]}; i++ )); do
    IFS=':' read -r name mask weight desc <<< "${entries[$i]}"
    if [[ ! "${weight}" =~ ^[0-9]+$ || "${weight}" -le 0 ]]; then weight=1; fi
    cumulative=$(( cumulative + weight ))
    if (( target_slot < cumulative )); then
      printf "%s" "${i}"
      return 0
    fi
  done
  printf 0
}

function select_weighted_pattern_index {
  local cursor=$1 raw_patterns=$2 total slot
  total=$(calculate_pattern_weight_total "${raw_patterns}")
  [[ "${total}" -le 0 ]] && { printf 0; return 0; }
  slot=$(( cursor % total ))
  select_pattern_index_by_slot "${slot}" "${raw_patterns}"
}

function select_random_pattern_index {
  local raw_patterns=$1 total slot
  total=$(calculate_pattern_weight_total "${raw_patterns}")
  [[ "${total}" -le 0 ]] && { printf 0; return 0; }
  slot=$(( RANDOM % total ))
  select_pattern_index_by_slot "${slot}" "${raw_patterns}"
}
