# Bruteforce Bootloader Unlocker

A modular, Fastboot-first shell automation suite for authorized bootloader unlocking and candidate code evaluation on Android devices. It detects fastboot unlock command profiles, executes pattern DSL schedules, provides atomic persistence, and features a responsive terminal UI.

> **Legal & Safety Notice:** Use only on devices you legally own or are explicitly authorized to service. This tool does not bypass carrier locks, enterprise management policies (EMM/MDM), Factory Reset Protection (FRP), or hardware security fuses. Unlocking a bootloader will erase user data and may void manufacturer warranties.

---

## Key Features

- **Modular Architecture:** Cleanly decomposed into focused subsystems in `lib/` adhering to Object Calisthenics and SOLID principles.
- **Fastboot Profile Auto-Detection:** Automatically probes device capabilities to infer the safe unlock flow:
  - `fastboot flashing unlock` (AOSP / Google Pixel)
  - `fastboot oem unlock <code>` (Motorola / OEM tokens)
  - `fastboot flashing unlock <code>`
  - `fastboot oem unlock` (Legacy devices)
  - `fastboot oem unlock-go`
- **Pattern DSL Engine:** Express candidate key spaces cleanly (e.g. `X{20}`, `A{19}9`, `9{6}`, `H{32}`, `XXXX-XXXX`).
- **Smart Weighted Scheduling:** Prioritizes high-probability patterns before expanding to wider search spaces.
- **Atomic State Persistence:** Safely saves per-device cursors to `<device>.dat` using atomic filesystem operations to prevent corruption on sudden termination.
- **Cross-Platform & Environment Aware:** Native Linux, macOS, and Windows/WSL (with automatic carriage-return filtering and `fastboot.exe` fallback).
- **Responsive CLI Experience:** Dynamic terminal width calculation, ANSI color semantics, real-time progress indicators, and `NO_COLOR` compliance.

---

## Quick Start

### 1. Requirements

- Bash 4.0+ (Linux, macOS, or WSL2)
- Android SDK Platform Tools (`fastboot` and optionally `adb` in PATH)
- USB connection with fastboot access permissions
- Device booted into Fastboot/Bootloader mode (`adb reboot bootloader`)

### 2. Installation

```bash
git clone https://github.com/samuelcaldas/bruteforce-bootloader-unlocker.git
cd bruteforce-bootloader-unlocker
chmod +x bootloader_unlocker
```

### 3. Basic Execution

```bash
# Auto-detect device and profile, run default smart pattern schedule
./bootloader_unlocker

# Display help and options
./bootloader_unlocker --help

# List built-in pattern masks and priority weights
./bootloader_unlocker --list-patterns
```

---

## Usage & CLI Options

```text
Fastboot Bootloader Unlock Console

Usage: ./bootloader_unlocker [options]

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
```

---

## Pattern DSL Specification

| Symbol | Description | Character Set |
|---|---|---|
| `9` | Numeric digit | `0-9` |
| `A` | Uppercase alphabetic | `A-Z` |
| `a` | Lowercase alphabetic | `a-z` |
| `X` | Uppercase alphanumeric | `A-Z, 0-9` |
| `x` | Mixed alphanumeric | `A-Z, a-z, 0-9` |
| `H` | Uppercase hexadecimal | `0-9, A-F` |
| `h` | Lowercase hexadecimal | `0-9, a-f` |
| `?` | Active charset symbol | Selected by `--type` |
| `{n}` | Repeat multiplier | e.g. `X{20}`, `A{4}9A{15}`, `9{6}` |
| Literal | Any literal character | Hyphens, colons preserved (e.g. `XXXX-XXXX`) |

### Example Pattern Invocations

```bash
# Run 20-character uppercase alphanumeric pattern
./bootloader_unlocker --pattern 'X{20}' --command oem-unlock-code

# Custom weighted multi-pattern schedule
./bootloader_unlocker --patterns 'moto:X{20}:10;pin6:9{6}:1' --strategy smart
```

---

## Documentation Index

- [Architecture & Modular Subsystems](docs/ARCHITECTURE.md)
- [Pattern DSL Grammar & Search Space](docs/PATTERN_DSL.md)
- [Fastboot Command Profiles](docs/COMMAND_PROFILES.md)
- [Design System & Terminal UI](docs/DESIGN.md)
- [Automated Testing Framework](docs/TESTING.md)

---

## Running Tests

The test suite requires only Bash and standard coreutils (no external test runner dependencies):

```bash
# Run all syntax checks, unit tests, and integration tests
bash tests/run_all_tests.sh

# Run a specific unit test file
bash tests/unit/test_pattern_engine.sh

# Run with test filter
bash tests/run_all_tests.sh fastboot
```

---

## License

This project is open-source under the [MIT License](LICENSE).
