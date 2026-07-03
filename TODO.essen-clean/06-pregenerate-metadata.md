# TODO 06 — Pre-generate metadata for Unicode 15.0, 15.1, 16.0, 17.0

## Status

Pending. Depends on TODO 05.

## Context

The gem must ship metadata modules for all supported Unicode versions
(15.0.0, 15.1.0, 16.0.0, 17.0.0). Each requires downloading that
version's UCD, running the generator, and committing the output.

## Steps (per version)

For each version V in `["15.0.0", "15.1.0", "16.0.0", "17.0.0"]`:

1. `ucode fetch ucd --version V`
2. `ucode emit-metadata --version V`
3. Verify the generated file:
   - `ruby -c lib/ucode/unicode/metadata/v<V_underscores>.rb`
   - `ASSIGNED_COUNT` is positive and plausible
   - `BLOCKS.size` matches `Blocks.txt` line count
4. Add autoload entry to `lib/ucode/unicode.rb`
5. Commit

## Expected block counts (approximate)

| Version  | Blocks | Assigned (approx) |
|----------|--------|-------------------|
| 15.0.0   | ~329   | ~149_186          |
| 15.1.0   | ~331   | ~149_878          |
| 16.0.0   | ~336   | ~155_063          |
| 17.0.0   | ~346   | ~159_866          |

(The exact counts will be computed by the generator — these are
sanity-check ranges.)

## Version registry update

After all four are generated, `lib/ucode/unicode.rb` declares:

```ruby
module Unicode
  SUPPORTED_VERSIONS = %w[15.0.0 15.1.0 16.0.0 17.0.0].freeze
  LATEST_VERSION = "17.0.0".freeze

  module Metadata
    autoload :V15_0_0, "ucode/unicode/metadata/v15_0_0"
    autoload :V15_1_0, "ucode/unicode/metadata/v15_1_0"
    autoload :V16_0_0, "ucode/unicode/metadata/v16_0_0"
    autoload :V17_0_0, "ucode/unicode/metadata/v17_0_0"
  end
end
```

## Acceptance criteria

- 4 metadata files exist and load without error
- `Ucode::Unicode.for_version("15.0.0").assigned_count` is different from `for_version("17.0.0").assigned_count`
- Each version's `BLOCKS` count matches its `Blocks.txt`
- All files pass `rubocop` (generated code must be clean)
- All files have the auto-generation header comment
