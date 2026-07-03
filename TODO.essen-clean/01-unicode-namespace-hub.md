# TODO 01 — `Ucode::Unicode` namespace hub + version registry

## Status

Pending. Foundation for TODOs 02-10.

## Context

Issues #62 + #63 ask for a Ruby API over Unicode metadata. The API must
support **multiple Unicode versions** (15.0, 15.1, 16.0, 17.0, and future
releases) because consumers audit fonts that target different Unicode
versions. A single static metadata file does not work — the data must be
version-keyed.

## Decision: generated Ruby modules per version

Each Unicode version gets a generated Ruby module under
`lib/ucode/unicode/metadata/` (committed to the gem, NOT in the
gitignored `data/` directory):

```
lib/ucode/unicode/metadata/
├── v15_0_0.rb    # module Ucode::Unicode::Metadata::V15_0_0
├── v15_1_0.rb
├── v16_0_0.rb
└── v17_0_0.rb
```

**Why Ruby modules, not JSON files:**
- No runtime JSON parsing — constants are loaded via autoload
- Compile-time syntax checking — bad metadata fails at load, not at query
- Frozen constants — thread-safe, O(1) access
- Path resolution via `__dir__` — no gem-root guessing

## Files

- `lib/ucode/unicode.rb` — namespace hub (NEW)
- `lib/ucode/error.rb` — add `UnknownUnicodeVersionError` (NEW error class)

## API surface

```ruby
module Ucode
  module Unicode
    # All Unicode versions this gem ships metadata for.
    SUPPORTED_VERSIONS = %w[15.0.0 15.1.0 16.0.0 17.0.0].freeze

    # The newest version — used when the caller doesn't specify one.
    LATEST_VERSION = "17.0.0".freeze

    # Delegation to the latest version (convenience for the common case)
    def self.assigned_count = for_version(LATEST_VERSION).assigned_count
    def self.unicode_version = LATEST_VERSION

    # Factory: returns a Catalog bound to the given version.
    # Accepts short forms ("16", "16.0") and normalizes to full ("16.0.0").
    # Raises UnknownUnicodeVersionError for unsupported versions.
    def self.for_version(version = LATEST_VERSION)
      # ...
    end
  end
end
```

## Version normalization

Consumers may pass `"16"`, `"16.0"`, or `"16.0.0"`. The hub normalizes:

| Input      | Normalized  |
|------------|-------------|
| `"17"      | `"17.0.0"`  |
| `"16.0"    | `"16.0.0"`  |
| `"15.1"    | `"15.1.0"`  |
| `"17.0.0"  | `"17.0.0"`  |
| `"99.0.0"  | raise       |

Normalization rule: pad missing components with `.0`. Then validate
against `SUPPORTED_VERSIONS`.

## Relationship to existing `Ucode::Config::KNOWN_VERSIONS`

`Ucode::Unicode::SUPPORTED_VERSIONS` mirrors
`Ucode::Config::KNOWN_VERSIONS`. When a new Unicode version is added:

1. Add to `Config::KNOWN_VERSIONS`
2. Generate metadata module under `metadata/`
3. Add to `Unicode::SUPPORTED_VERSIONS`
4. Update `Unicode::LATEST_VERSION` if it's the newest

This is a 4-line OCP extension — no existing code changes.

## Acceptance criteria

- `Ucode::Unicode` module loads without requiring UCD data on disk
- `Ucode::Unicode::SUPPORTED_VERSIONS` returns the 4 versions
- `Ucode::Unicode::LATEST_VERSION` returns `"17.0.0"`
- `Ucode::Unicode.for_version("16")` resolves to `"16.0.0"` catalog
- `Ucode::Unicode.for_version("99")` raises `UnknownUnicodeVersionError`
- No `require_relative` — all autoloads declared in `lib/ucode/unicode.rb`
