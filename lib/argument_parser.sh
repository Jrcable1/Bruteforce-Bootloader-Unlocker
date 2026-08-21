#!/usr/bin/env bash
# ==============================================================================
# argument_parser.sh - CLI argument parsing, input validation, and help guide
# ==============================================================================

[[ -n "${ARGUMENT_PARSER_INCLUDED:-}" ]] && return 0
readonly ARGUMENT_PARSER_INCLUDED=1

function display_usage_guide {
  cat <<EOF
Fastboot Bootloader Unlock Console

Usage: $0 [options]

Core Options:
  -h, --help                 Display this help guide and exit
  -d, --device <id>          Target fastboot device identifier (default: auto-detect)
  -c, --command <profile>    Command profile: auto, flashing-unlock, flashing-unlock-code,
                             oem-unlock-code, oem-unlock, oem-unlock-go (default: auto)
  --strategy <strategy>      Candidate order: smart, sequential, random (default: smart)
  -s, --start <offset>       Resume or start from numeric offset (default: 0)

Pattern DSL Options:
  -p, --pattern <mask>       Apply single pattern mask, e.g. 'X{20}', 'A{19}9', '9{6}'
  --patterns <schedule>      Semicolon-delimited list: name:mask:weight;name:mask:weight
  --list-patterns            Display built-in pattern profiles and priority schedule

Legacy Options:
  -t, --type <type>          Legacy charset alias: moto, alpha, numeric (default: moto)
  -l, --length <num>         Code length for generic search (default: 20)

Pattern DSL Tokens:
  9   Numeric digit             0-9
  A   Uppercase alphabetic      A-Z
  a   Lowercase alphabetic      a-z
  X   Uppercase alphanumeric    A-Z, 0-9
  x   Mixed alphanumeric        A-Z, a-z, 0-9
  H   Uppercase hexadecimal     0-9, A-F
  h   Lowercase hexadecimal     0-9, a-f
  ?   Active charset symbol     Selected by --type
  {n} Repeat multiplier         e.g. A{4}9A{15}, X{20}, 9{6}
  *   Literal characters        Hyphens, colons, or separators preserved (e.g. XXXX-XXXX)

Examples:
  $0 --command auto --strategy smart
  $0 --pattern 'X{20}' --command oem-unlock-code
  $0 --patterns 'moto:X{20}:10;pin6:9{6}:1' --device ZY2234ABCD
EOF
}

function display_builtin_patterns {
  printf "Built-in pattern profiles (highest priority first):\n\n"
  printf "  %-22s %-12s %-8s %s\n" "PROFILE NAME" "MASK" "WEIGHT" "DESCRIPTION"
  printf "  %-22s %-12s %-8s %s\n" "------------" "----" "------" "-----------"

  IFS=';' read -ra entries <<< "${BUILTIN_PATTERN_PROFILES}"
  for entry in "${entries[@]}"; do
    IFS=':' read -r name mask weight desc <<< "${entry}"
    printf "  %-22s %-12s %-8s %s\n" "${name}" "${mask}" "${weight}" "${desc}"
  done
}

function parse_cli_arguments {
  CLI_DEVICE_OVERRIDE=""
  CLI_CODE_TYPE=""
  CLI_CODE_LENGTH=""
  CLI_START_OFFSET=""
  CLI_SINGLE_PATTERN=""
  CLI_PATTERN_SCHEDULE=""
  CLI_STRATEGY=""
  CLI_COMMAND_PROFILE=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        display_usage_guide
        exit "${EXIT_SUCCESS}"
        ;;
      --list-patterns)
        display_builtin_patterns
        exit "${EXIT_SUCCESS}"
        ;;
      -d|--device)
        [[ -z "${2:-}" ]] && { ui_fail "Missing value for --device"; exit "${EXIT_GENERAL_ERROR}"; }
        CLI_DEVICE_OVERRIDE="$2"; shift 2 ;;
      -t|--type)
        [[ -z "${2:-}" ]] && { ui_fail "Missing value for --type"; exit "${EXIT_GENERAL_ERROR}"; }
        CLI_CODE_TYPE="$2"; shift 2 ;;
      -l|--length)
        [[ -z "${2:-}" ]] && { ui_fail "Missing value for --length"; exit "${EXIT_GENERAL_ERROR}"; }
        CLI_CODE_LENGTH="$2"; shift 2 ;;
      -s|--start)
        [[ -z "${2:-}" ]] && { ui_fail "Missing value for --start"; exit "${EXIT_GENERAL_ERROR}"; }
        CLI_START_OFFSET="$2"; shift 2 ;;
      -p|--pattern)
        [[ -z "${2:-}" ]] && { ui_fail "Missing value for --pattern"; exit "${EXIT_GENERAL_ERROR}"; }
        CLI_SINGLE_PATTERN="$2"; shift 2 ;;
      --patterns)
        [[ -z "${2:-}" ]] && { ui_fail "Missing value for --patterns"; exit "${EXIT_GENERAL_ERROR}"; }
        CLI_PATTERN_SCHEDULE="$2"; shift 2 ;;
      --strategy)
        [[ -z "${2:-}" ]] && { ui_fail "Missing value for --strategy"; exit "${EXIT_GENERAL_ERROR}"; }
        CLI_STRATEGY="$2"; shift 2 ;;
      -c|--command)
        [[ -z "${2:-}" ]] && { ui_fail "Missing value for --command"; exit "${EXIT_GENERAL_ERROR}"; }
        CLI_COMMAND_PROFILE="$2"; shift 2 ;;
      *)
        ui_fail "Unknown argument: $1"
        printf "Run '%s --help' for available options.\n" "$0"
        exit "${EXIT_GENERAL_ERROR}"
        ;;
    esac
  done
}
