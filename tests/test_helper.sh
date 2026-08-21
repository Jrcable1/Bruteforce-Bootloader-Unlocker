#!/usr/bin/env bash
# ==============================================================================
# test_helper.sh - Standalone TAP test framework, assertions, and mock engine
# ==============================================================================

# Derive repository locations
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
LIB_DIR="${REPO_ROOT}/lib"
CLI_BIN="${REPO_ROOT}/bootloader_unlocker"

readonly TESTS_DIR REPO_ROOT LIB_DIR CLI_BIN

# Global TAP state
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
TEST_START_TIME=$(date +%s)
CURRENT_SANDBOX=""
ORIGINAL_CWD=""

# ------------------------------------------------------------------------------
# Assertion Engine
# ------------------------------------------------------------------------------

function assert_eq {
  local expected=$1 actual=$2 msg=${3:-"assert_eq failed"}
  if [[ "${expected}" != "${actual}" ]]; then
    printf "# [FAIL] %s\n" "${msg}" >&2
    printf "#   Expected: %q\n" "${expected}" >&2
    printf "#   Actual:   %q\n" "${actual}" >&2
    return 1
  fi
  return 0
}

function assert_not_eq {
  local unexpected=$1 actual=$2 msg=${3:-"assert_not_eq failed"}
  if [[ "${unexpected}" == "${actual}" ]]; then
    printf "# [FAIL] %s\n" "${msg}" >&2
    printf "#   Unexpected: %q\n" "${unexpected}" >&2
    printf "#   Actual:     %q\n" "${actual}" >&2
    return 1
  fi
  return 0
}

function assert_status {
  local expected=$1 actual=$2 msg=${3:-"assert_status failed"}
  if [[ "${expected}" -ne "${actual}" ]]; then
    printf "# [FAIL] %s\n" "${msg}" >&2
    printf "#   Expected status: %d\n" "${expected}" >&2
    printf "#   Actual status:   %d\n" "${actual}" >&2
    return 1
  fi
  return 0
}

function assert_file_exists {
  local path=$1 msg=${2:-"assert_file_exists failed"}
  if [[ ! -f "${path}" ]]; then
    printf "# [FAIL] %s\n" "${msg}" >&2
    printf "#   File not found: %s\n" "${path}" >&2
    return 1
  fi
  return 0
}

function assert_file_not_exists {
  local path=$1 msg=${2:-"assert_file_not_exists failed"}
  if [[ -e "${path}" ]]; then
    printf "# [FAIL] %s\n" "${msg}" >&2
    printf "#   File should not exist: %s\n" "${path}" >&2
    return 1
  fi
  return 0
}

function assert_dir_exists {
  local path=$1 msg=${2:-"assert_dir_exists failed"}
  if [[ ! -d "${path}" ]]; then
    printf "# [FAIL] %s\n" "${msg}" >&2
    printf "#   Directory not found: %s\n" "${path}" >&2
    return 1
  fi
  return 0
}

function assert_matches {
  local value=$1 regex=$2 msg=${3:-"assert_matches failed"}
  if [[ ! "${value}" =~ ${regex} ]]; then
    printf "# [FAIL] %s\n" "${msg}" >&2
    printf "#   Value: %q\n" "${value}" >&2
    printf "#   Regex: %s\n" "${regex}" >&2
    return 1
  fi
  return 0
}

function assert_contains {
  local haystack=$1 needle=$2 msg=${3:-"assert_contains failed"}
  if [[ "${haystack}" != *"${needle}"* ]]; then
    printf "# [FAIL] %s\n" "${msg}" >&2
    printf "#   Needle:   %q\n" "${needle}" >&2
    printf "#   Haystack: %q\n" "${haystack}" >&2
    return 1
  fi
  return 0
}

function assert_not_contains {
  local haystack=$1 needle=$2 msg=${3:-"assert_not_contains failed"}
  if [[ "${haystack}" == *"${needle}"* ]]; then
    printf "# [FAIL] %s\n" "${msg}" >&2
    printf "#   Needle should not be in haystack: %q\n" "${needle}" >&2
    return 1
  fi
  return 0
}

function assert_no_ansi {
  local value=$1 msg=${2:-"assert_no_ansi failed"}
  local ansi_pattern=$'\033\\[[0-9;]*[a-zA-Z]'
  if [[ "${value}" =~ ${ansi_pattern} ]]; then
    printf "# [FAIL] %s\n" "${msg}" >&2
    printf "#   Value contains ANSI escape sequences: %q\n" "${value}" >&2
    return 1
  fi
  return 0
}

function assert_empty {
  local value=$1 msg=${2:-"assert_empty failed"}
  if [[ -n "${value}" ]]; then
    printf "# [FAIL] %s\n" "${msg}" >&2
    printf "#   Expected empty value, got: %q\n" "${value}" >&2
    return 1
  fi
  return 0
}

function assert_success {
  local status=$1 msg=${2:-"assert_success failed"}
  assert_status 0 "${status}" "${msg}"
}

function assert_failure {
  local status=$1 msg=${2:-"assert_failure failed"}
  if [[ "${status}" -eq 0 ]]; then
    printf "# [FAIL] %s: expected failure status, got 0\n" "${msg}" >&2
    return 1
  fi
  return 0
}

# ------------------------------------------------------------------------------
# Sandbox Management
# ------------------------------------------------------------------------------

function setup_test_sandbox {
  ORIGINAL_CWD="${PWD}"
  CURRENT_SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/bbu_test_XXXXXX")
  mkdir -p "${CURRENT_SANDBOX}/bin"
  export TEST_SANDBOX="${CURRENT_SANDBOX}"
  export HOME="${CURRENT_SANDBOX}"
  export XDG_CONFIG_HOME="${CURRENT_SANDBOX}/.config"
  export XDG_CACHE_HOME="${CURRENT_SANDBOX}/.cache"
  export XDG_STATE_HOME="${CURRENT_SANDBOX}/.local/state"
  export TMPDIR="${CURRENT_SANDBOX}/tmp"
  mkdir -p "${XDG_CONFIG_HOME}" "${XDG_CACHE_HOME}" "${XDG_STATE_HOME}" "${TMPDIR}"
  export PATH="${CURRENT_SANDBOX}/bin:${PATH}"
  cd "${CURRENT_SANDBOX}"
}

function cleanup_test_sandbox {
  if [[ -n "${ORIGINAL_CWD:-}" && -d "${ORIGINAL_CWD}" ]]; then
    cd "${ORIGINAL_CWD}" || true
  fi
  if [[ -n "${CURRENT_SANDBOX:-}" && -d "${CURRENT_SANDBOX}" ]]; then
    if [[ "${CURRENT_SANDBOX}" =~ bbu_test_ ]]; then
      rm -rf "${CURRENT_SANDBOX}" 2>/dev/null || true
    fi
  fi
}

# ------------------------------------------------------------------------------
# Execution & Output Capture
# ------------------------------------------------------------------------------

function run_capture {
  local stdout_f stderr_f status=0
  stdout_f=$(mktemp "${TMPDIR:-/tmp}/stdout_XXXXXX")
  stderr_f=$(mktemp "${TMPDIR:-/tmp}/stderr_XXXXXX")

  set +e
  ( "$@" ) >"${stdout_f}" 2>"${stderr_f}"
  status=$?
  set -e

  CAPTURE_STATUS="${status}"
  CAPTURE_STDOUT=$(cat "${stdout_f}")
  CAPTURE_STDERR=$(cat "${stderr_f}")
  CAPTURE_OUTPUT="${CAPTURE_STDOUT}"
  if [[ -n "${CAPTURE_STDERR}" ]]; then
    CAPTURE_OUTPUT=$(printf "%s\n%s" "${CAPTURE_STDOUT}" "${CAPTURE_STDERR}")
  fi

  rm -f "${stdout_f}" "${stderr_f}"
  return 0
}

function run_capture_with_stdin {
  local input=$1 stdout_f stderr_f status=0
  shift
  stdout_f=$(mktemp "${TMPDIR:-/tmp}/stdout_XXXXXX")
  stderr_f=$(mktemp "${TMPDIR:-/tmp}/stderr_XXXXXX")

  set +e
  ( printf "%s\n" "${input}" | "$@" ) >"${stdout_f}" 2>"${stderr_f}"
  status=$?
  set -e

  CAPTURE_STATUS="${status}"
  CAPTURE_STDOUT=$(cat "${stdout_f}")
  CAPTURE_STDERR=$(cat "${stderr_f}")
  CAPTURE_OUTPUT="${CAPTURE_STDOUT}"
  if [[ -n "${CAPTURE_STDERR}" ]]; then
    CAPTURE_OUTPUT=$(printf "%s\n%s" "${CAPTURE_STDOUT}" "${CAPTURE_STDERR}")
  fi

  rm -f "${stdout_f}" "${stderr_f}"
  return 0
}

# ------------------------------------------------------------------------------
# Mock Creation Helpers
# ------------------------------------------------------------------------------

function make_mock_executable {
  local name=$1 body=$2 dest
  dest="${CURRENT_SANDBOX}/bin/${name}"
  cat <<EOF > "${dest}"
#!/usr/bin/env bash
${body}
EOF
  chmod +x "${dest}"
}

function create_mock_fastboot {
  local mock_script
  mock_script=$(cat <<'EOF'
#!/usr/bin/env bash
# Fastboot Mock Simulator

# Log invocations if requested
if [[ -n "${MOCK_FASTBOOT_LOG:-}" ]]; then
  printf "%s\n" "$*" >> "${MOCK_FASTBOOT_LOG}"
fi

# Track command counter if file configured
if [[ -n "${MOCK_FASTBOOT_COUNTER_FILE:-}" ]]; then
  count=1
  if [[ -f "${MOCK_FASTBOOT_COUNTER_FILE}" ]]; then
    count=$(( $(cat "${MOCK_FASTBOOT_COUNTER_FILE}") + 1 ))
  fi
  printf "%d" "${count}" > "${MOCK_FASTBOOT_COUNTER_FILE}"
fi

# 1. Version request
if [[ "$1" == "--version" ]]; then
  printf "fastboot version %s\n" "${MOCK_FASTBOOT_VERSION:-34.0.5-mock}"
  exit 0
fi

# 2. Devices request
if [[ "$1" == "devices" ]]; then
  printf "%s\n" "${MOCK_FASTBOOT_DEVICES-ZY22345678	fastboot}"
  exit 0
fi

# 3. Targeted commands (-s <device> <cmd...>)
if [[ "$1" == "-s" ]]; then
  device="$2"
  shift 2

  cmd="$1"
  subcmd="${2:-}"
  code="${3:-}"

  # get_unlock_ability
  if [[ "${cmd}" == "flashing" && "${subcmd}" == "get_unlock_ability" ]]; then
    ability="${MOCK_FASTBOOT_UNLOCK_ABILITY:-0}"
    printf "(bootloader) unlock_ability: %s\nOKAY [  0.005s]\nfinished. total time: 0.005s\n" "${ability}"
    exit 0
  fi

  # get_unlock_data
  if [[ "${cmd}" == "oem" && "${subcmd}" == "get_unlock_data" ]]; then
    if [[ -n "${MOCK_FASTBOOT_UNLOCK_DATA:-}" ]]; then
      printf "%s\n" "${MOCK_FASTBOOT_UNLOCK_DATA}"
      exit 0
    else
      printf "(bootloader) 3A99240409204245#41323838383838\n(bootloader) 3432323233343536#1234567890ABCDEF\n(bootloader) 1234567890ABCDEF#1234567890ABCDEF\nOKAY [  0.010s]\nfinished.\n"
      exit 0
    fi
  fi

  # getvar product
  if [[ "${cmd}" == "getvar" && "${subcmd}" == "product" ]]; then
    product="${MOCK_FASTBOOT_PRODUCT:-aljeter}"
    printf "product: %s\nfinished. total time: 0.002s\n" "${product}"
    exit 0
  fi

  # Terminal mode simulation
  if [[ "${MOCK_FASTBOOT_MODE:-}" == "terminal_carrier" ]]; then
    printf "FAILED (remote: device is locked by carrier)\nfinished.\n"
    exit 1
  fi
  if [[ "${MOCK_FASTBOOT_MODE:-}" == "terminal_frp" ]]; then
    printf "FAILED (remote: flashing unlock is not allowed by FRP)\nfinished.\n"
    exit 1
  fi
  if [[ "${MOCK_FASTBOOT_MODE:-}" == "terminal_unsupported" ]]; then
    printf "FAILED (remote: unknown command)\nfinished.\n"
    exit 1
  fi

  # Direct unlock (flashing unlock / oem unlock / oem unlock-go)
  if [[ ("${cmd}" == "flashing" && "${subcmd}" == "unlock" && -z "${code}") || \
        ("${cmd}" == "oem" && "${subcmd}" == "unlock" && -z "${code}") || \
        ("${cmd}" == "oem" && "${subcmd}" == "unlock-go") ]]; then
    if [[ "${MOCK_FASTBOOT_MODE:-}" == "fail_direct" ]]; then
      printf "FAILED (remote: unlock failed)\nfinished.\n"
      exit 1
    fi
    printf "OKAY [  1.200s]\nfinished. total time: 1.200s\n"
    exit 0
  fi

  # Code evaluation (flashing unlock <code> or oem unlock <code>)
  candidate="${code}"
  if [[ -z "${candidate}" && -n "${subcmd}" && "${subcmd}" != "unlock" ]]; then
    candidate="${subcmd}"
  fi

  success_code="${MOCK_FASTBOOT_SUCCESS_CODE:-SUCCESS1234567890}"
  if [[ -n "${candidate}" && "${candidate}" == "${success_code}" ]]; then
    printf "OKAY [  0.500s]\nUnlock data verified. Device unlocked.\nfinished. total time: 0.500s\n"
    exit 0
  fi

  printf "FAILED (remote: Check password failed!)\nfinished. total time: 0.050s\n"
  exit 1
fi

printf "fastboot: unsupported mock command: %s\n" "$*" >&2
exit 1
EOF
)
  make_mock_executable "fastboot" "${mock_script}"
  export FASTBOOT_BIN="${CURRENT_SANDBOX}/bin/fastboot"
}

# ------------------------------------------------------------------------------
# Test Runner & TAP Formatter
# ------------------------------------------------------------------------------

function run_test {
  local desc=$1 test_fn=$2

  if [[ -n "${TEST_FILTER:-}" ]]; then
    if [[ "${desc}" != *"${TEST_FILTER}"* ]]; then
      SKIP_COUNT=$(( SKIP_COUNT + 1 ))
      printf "ok %d - %s # SKIP filtered out\n" "$(( TEST_COUNT + 1 ))" "${desc}"
      TEST_COUNT=$(( TEST_COUNT + 1 ))
      return 0
    fi
  fi

  TEST_COUNT=$(( TEST_COUNT + 1 ))
  local current_idx="${TEST_COUNT}"

  # Run in subshell with isolated sandbox and environment
  (
    setup_test_sandbox
    trap cleanup_test_sandbox EXIT INT TERM
    set -euo pipefail
    "${test_fn}"
  )
  local status=$?

  if [[ ${status} -eq 0 ]]; then
    PASS_COUNT=$(( PASS_COUNT + 1 ))
    printf "ok %d - %s\n" "${current_idx}" "${desc}"
  else
    FAIL_COUNT=$(( FAIL_COUNT + 1 ))
    printf "not ok %d - %s\n" "${current_idx}" "${desc}"
  fi
}

function finish_tests {
  local duration=$(( $(date +%s) - TEST_START_TIME ))
  printf "\n1..%d\n" "${TEST_COUNT}"
  printf "# TEST_SUMMARY total=%d passed=%d failed=%d skipped=%d duration=%ds\n" \
    "${TEST_COUNT}" "${PASS_COUNT}" "${FAIL_COUNT}" "${SKIP_COUNT}" "${duration}"

  if [[ "${FAIL_COUNT}" -gt 0 ]]; then
    return 1
  fi
  return 0
}
