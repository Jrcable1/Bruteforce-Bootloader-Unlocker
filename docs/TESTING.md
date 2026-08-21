# Automated Testing Framework

## Overview

The Fastboot Bootloader Unlocker test suite provides automated, zero-hardware test coverage across all library subsystems and the CLI entrypoint. It utilizes pure Bash subshell isolation, sandboxed execution directories, and a mock Fastboot simulator.

---

## Test Suite Structure

```text
tests/
├── test_helper.sh              # TAP harness, assertions, sandbox lifecycle, mock fastboot engine
├── run_all_tests.sh            # Master runner (bash -n syntax validation + discovery & execution)
├── unit/                       # Subsystem-level isolated unit tests
│   ├── test_constants.sh       # Exit codes, limits, charsets, and profile parsing
│   ├── test_terminal_ui.sh     # ANSI styles, NO_COLOR/dumb fallbacks, and layout
│   ├── test_device_storage.sh  # State loading, sanitization, and atomic writes
│   ├── test_pattern_engine.sh  # Pattern DSL expansion, combinations, and scheduling
│   ├── test_fastboot_client.sh # Transport resolution, autodetection, and classifiers
│   ├── test_argument_parser.sh # CLI flags, numeric validation, and usage guide
│   └── test_unlock_runner.sh   # Formatters, authorization guard, and candidate loops
└── integration/
    └── test_cli_workflow.sh    # End-to-end CLI runs with mock fastboot and state persistence
```

---

## Running Tests

### 1. Run Complete Test Suite
```bash
bash tests/run_all_tests.sh
```

### 2. Run Specific Subsystem Tests
```bash
# Run pattern engine unit tests
bash tests/unit/test_pattern_engine.sh

# Run end-to-end CLI integration tests
bash tests/integration/test_cli_workflow.sh
```

### 3. Filtered Test Execution
```bash
# Filter test suites by pattern
bash tests/run_all_tests.sh pattern

# Filter by description substring
TEST_FILTER="atomic" bash tests/run_all_tests.sh
```

### 4. Non-TTY and Color-Disabled Testing
```bash
NO_COLOR=1 bash tests/run_all_tests.sh
TERM=dumb bash tests/run_all_tests.sh
```

---

## Assertion API

All test cases utilize the built-in assertion engine from `tests/test_helper.sh`:

- `assert_eq <expected> <actual> [msg]`: Exact string or numeric equality.
- `assert_not_eq <unexpected> <actual> [msg]`: Inverted equality.
- `assert_status <expected_code> <actual_code> [msg]`: Process/function exit status code.
- `assert_file_exists <path> [msg]`: Asserts presence of target file.
- `assert_file_not_exists <path> [msg]`: Asserts absence of target file.
- `assert_matches <string> <regex> [msg]`: Evaluates bash regular expression.
- `assert_contains <haystack> <needle> [msg]`: Substring containment check.
- `assert_not_contains <haystack> <needle> [msg]`: Inverted substring check.
- `assert_no_ansi <string> [msg]`: Asserts absence of ANSI escape sequences.
- `assert_empty <string> [msg]`: Asserts variable is empty string.
