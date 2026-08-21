# CLI Design System & Visual Hierarchy

## Design Principles

The terminal interface follows the **Impeccable** craftsmanship standard:
- **Scanability First:** High contrast semantic cues (`[OK]`, `[WARN]`, `[ERR]`, `[INFO]`, `[PLAN]`, `[RUN]`).
- **Responsive Geometry:** Automatically adapts layout and progress lines to `$COLUMNS` width.
- **Graceful Degradation:** Respects `NO_COLOR`, `TERM=dumb`, and non-TTY execution contexts.
- **Clean Alignment:** Aligned table columns and consistent spacing hierarchy.

---

## Token & Color Palette

| Token Role | Color | ANSI Code | Semantic Purpose |
|---|---|---|---|
| Primary Brand | Cyan | `\033[36m` | Console banner, primary section headers, flags |
| Success / OK | Green | `\033[32m` | Completed actions, verified unlock codes |
| Warning | Yellow | `\033[33m` | Fallbacks, advisory messages, DSL tokens |
| Error / Danger | Red | `\033[31m` | Dependency failures, device stops, terminal errors |
| Subdued / Meta | Dim / White | `\033[2m` / `\033[37m` | Metadata, scopes, table dividers |

---

## Layout Sections

1. **Header Banner:**
   ```text
   FASTBOOT UNLOCK CONSOLE
   scope: authorized devices only | transport: fastboot | mode: pattern search
   ────────────────────────────────────────────────────────────────
   ```

2. **Section Headings:**
   ```text
   [LINK] verifying local fastboot and adb tools
   [PROFILE] autodetecting safe fastboot unlock flow
   [PLAN] runtime execution profile
   [RULE] authorized use confirmation
   [RUN] starting unlock code evaluation
   ```

3. **Responsive Dynamic Progress Line:**
   ```text
   Trying: A3F9B2C1D4E5F6G7H8J9 | #1420 | motorola-portal-20 (X{20}) | Offset: 1420 | Progress: 0.001% | Elapsed: 45s | Est: 12h 30m
   ```
