#!/usr/bin/env bash
# ==============================================================================
# constants.sh - System constants, charsets, exit codes, and builtin profiles
# ==============================================================================

# Prevent duplicate inclusion
[[ -n "${CONSTANTS_INCLUDED:-}" ]] && return 0
readonly CONSTANTS_INCLUDED=1

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_TERMINAL_FASTBOOT_ERROR=2
readonly EXIT_INTERRUPTED=130

# Numeric boundary
readonly MAX_INTEGER_VALUE=9223372036854775807

# Defaults
readonly DEFAULT_CODE_LENGTH=20
readonly DEFAULT_STRATEGY="smart"
readonly DEFAULT_COMMAND_PROFILE="auto"
readonly DEFAULT_CODE_TYPE="moto"
readonly DEFAULT_UPDATE_INTERVAL=10
readonly DEFAULT_PERSIST_INTERVAL=100

# Character Sets
readonly CHARSET_DIGITS="0123456789"
readonly CHARSET_UPPER_ALPHA="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
readonly CHARSET_LOWER_ALPHA="abcdefghijklmnopqrstuvwxyz"
readonly CHARSET_UPPER_ALPHANUMERIC="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
readonly CHARSET_MIXED_ALPHANUMERIC="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
readonly CHARSET_HEX_UPPER="0123456789ABCDEF"
readonly CHARSET_HEX_LOWER="0123456789abcdef"

# Built-in Pattern DSL Profiles
# Format: name:mask:weight:description
readonly BUILTIN_PATTERN_PROFILES="motorola-portal-20:X{20}:10:Motorola official portal 20-character key;motorola-last-digit:A{19}9:6:Motorola-like key ending with numeric digit;motorola-pos5-digit:A{4}9A{15}:5:Motorola-like key with digit at position 5;hex-16:H{16}:3:16-character hexadecimal unlock token;hex-32:H{32}:2:32-character hexadecimal unlock token;numeric-8:9{8}:2:8-digit numeric unlock PIN;numeric-6:9{6}:1:6-digit numeric unlock PIN"
