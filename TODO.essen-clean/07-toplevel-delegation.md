# TODO 07 — Top-level delegation constants

## Status

Pending. Depends on TODOs 01, 04, 06.

## Context

Consumers like essenfont want one-line access to the common case:
`Ucode::ASSIGNED_COUNT` for the latest Unicode version. They shouldn't
need to write `Ucode::Unicode.for_version("17.0.0").assigned_count`
every time.

This TODO adds top-level delegation constants to the `Ucode` module.

## Files

- `lib/ucode.rb` — add autoload + delegation
- `lib/ucode/unicode.rb` — ensure hub is loaded

## Design

```ruby
module Ucode
  # ... existing autoloads ...

  autoload :Unicode, "ucode/unicode"

  # Convenience: latest Unicode version this gem ships metadata for.
  # Different from Ucode::VERSION (gem version, e.g. "0.3.0").
  def self.UNICODE_VERSION
    Unicode::LATEST_VERSION
  end

  # Convenience: total assigned codepoints in the latest Unicode version.
  # Computed from DerivedGeneralCategory.txt (GC ≠ Cn, Co, Cs).
  def self.ASSIGNED_COUNT
    Unicode.assigned_count
  end

  # Convenience: per-plane assigned breakdown for the latest version.
  def self.ASSIGNED_BY_PLANE
    Unicode.for_version.assigned_by_plane
  end
end
```

## Why methods, not constants?

Ruby constants are evaluated at load time. If we write
`ASSIGNED_COUNT = Unicode.assigned_count` at the top of `ucode.rb`,
it triggers loading the entire Unicode subsystem eagerly. Using methods
defers the load until first call, preserving autoload laziness.

However, for consumer ergonomics, `Ucode::ASSIGNED_COUNT` (constant
syntax) is nicer than `Ucode.ASSIGNED_COUNT` (method syntax).

**Resolution**: define methods, but also memoize as frozen constants
on first access. Or accept the method syntax — it's explicit about the
cost.

**Decision**: use methods. The first call triggers metadata load; subsequent
calls hit the frozen Catalog (O(1)). The uppercase naming signals
"constant-like" even though it's a method call.

## `Ucode::VERSION` vs `Ucode::UNICODE_VERSION`

| Constant           | Value    | Meaning                     |
|--------------------|----------|-----------------------------|
| `Ucode::VERSION`   | "0.3.0"  | Gem release version         |
| `Ucode::UNICODE_VERSION` | "17.0.0" | Unicode data version (latest) |

These are DIFFERENT. The gem version bumps per release; the Unicode
version only bumps when a new Unicode standard is supported.

## Acceptance criteria

- `Ucode.UNICODE_VERSION` returns `"17.0.0"`
- `Ucode.ASSIGNED_COUNT` returns `159_866` (or whatever Unicode 17.0 says)
- `Ucode.VERSION` still returns the gem version (`"0.3.0"`)
- No eager load — metadata modules load only on first call
- Thread-safe (Catalog memoizes, frozen data)
