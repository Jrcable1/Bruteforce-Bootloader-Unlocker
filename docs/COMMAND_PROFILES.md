# Fastboot Command Profiles

## Overview

Modern and legacy Android devices utilize varying Fastboot commands and payload formats to perform bootloader unlocks.

| Profile Name | Fastboot Command Syntax | Payload Required | Typical Target OEM / Generation |
|---|---|---|---|
| `flashing-unlock` | `fastboot flashing unlock` | No | AOSP, Google Pixel (Android 6.0+) |
| `flashing-unlock-code` | `fastboot flashing unlock <code>` | Yes (Code/Token) | Select modern OEM implementations |
| `oem-unlock-code` | `fastboot oem unlock <code>` | Yes (Key/Token) | Motorola, OnePlus, HTC, Huawei |
| `oem-unlock` | `fastboot oem unlock` | No | Legacy AOSP / Android 5.x and below |
| `oem-unlock-go` | `fastboot oem unlock-go` | No | Legacy OEM fastboot implementations |

---

## Safe Auto-Detection (`--command auto`)

When configured with `auto`, the unlocker issues safe non-destructive queries:

1. **AOSP Unlock Ability Probe:**
   ```bash
   fastboot flashing get_unlock_ability
   ```
   If ability returns `1`, `flashing-unlock` is selected.

2. **OEM Unlock Data Probe:**
   ```bash
   fastboot oem get_unlock_data
   ```
   If valid unlock data / token strings are returned, `oem-unlock-code` is selected.

3. **Product Variable Probe:**
   ```bash
   fastboot getvar product
   ```
   If identified as a Google Pixel family device, `flashing-unlock` is selected.

4. **Conservative Fallback:**
   If no-code flows cannot be proved, `oem-unlock-code` is selected as a safe default.

---

## Terminal Error Classifications

The client classifies responses into:
- **Success:** Exit code 0, no failure keyword.
- **Retryable Failure:** Invalid code, mismatch, or general remote error.
- **Terminal Rejection:** Device locked by carrier, FRP active, OEM unlocking disabled in Developer Options, or command unsupported by hardware. The script halts immediately to prevent device lockouts.
