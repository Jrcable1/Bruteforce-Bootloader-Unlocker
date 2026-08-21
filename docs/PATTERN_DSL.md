# Pattern DSL Specification

## Grammar & Syntax

The Pattern DSL allows concise specification of key spaces, structural formats, and known character ranges.

### Token Set

| Token | Character Range | Description |
|---|---|---|
| `9` | `0-9` | Decimal digit (base 10) |
| `A` | `A-Z` | Uppercase Latin alphabet (base 26) |
| `a` | `a-z` | Lowercase Latin alphabet (base 26) |
| `X` | `A-Z0-9` | Uppercase alphanumeric (base 36) |
| `x` | `A-Za-z0-9` | Mixed-case alphanumeric (base 62) |
| `H` | `0-9A-F` | Uppercase hexadecimal (base 16) |
| `h` | `0-9a-f` | Lowercase hexadecimal (base 16) |
| `?` | Active charset | Dynamically mapped by `--type` |
| `{n}` | Multiplier | Repeats preceding token `n` times |
| `*` | Literal | Any other character (e.g. `-`, `:`, `.`) preserved as literal |

---

## Repetition Syntax

Repetitions reduce verbose pattern declarations:

- `X{20}` expands to `XXXXXXXXXXXXXXXXXXXX` (20 uppercase alphanumeric characters).
- `A{4}9A{15}` expands to 4 uppercase letters, 1 digit, and 15 uppercase letters.
- `H{32}` expands to 32 uppercase hexadecimal characters.
- `XXXX-XXXX-XXXX` preserves `-` as structural delimiters.

---

## Combinations Space & Limits

The combination space $S$ for a pattern mask $M = (s_1, s_2, \dots, s_k)$ is given by:

$$S = \prod_{i=1}^{k} |C(s_i)|$$

where $|C(s_i)|$ is the cardinality of the character set corresponding to symbol $s_i$.

When $S > 2^{63} - 1$ (`9223372036854775807`), the engine marks the space as `huge`. In `huge` spaces:
- Percentage completion is represented as `n/a`.
- The generator produces valid candidate codes without integer overflow.

---

## Built-In Priority Profiles

```text
1. motorola-portal-20   (mask: X{20}, weight: 10)
2. motorola-last-digit  (mask: A{19}9, weight: 6)
3. motorola-pos5-digit  (mask: A{4}9A{15}, weight: 5)
4. hex-16               (mask: H{16}, weight: 3)
5. hex-32               (mask: H{32}, weight: 2)
6. numeric-8            (mask: 9{8}, weight: 2)
7. numeric-6            (mask: 9{6}, weight: 1)
```

In `smart` strategy mode, candidate selection distributes across these profiles proportionally to their weight:

$$P(\text{profile}_i) = \frac{\text{weight}_i}{\sum_j \text{weight}_j}$$
