# TODO 02 — Migrate `real_fonts/` to autoload

## Status

Pending. Audit finding V2 (critical rule violation).

## Why

`lib/ucode/glyphs/real_fonts/` has 5 `require_relative` calls for
internal library code:

- `writer.rb:6` — `require_relative "font_coverage_report"`
- `font_coverage_report.rb:5` — `require_relative "block_coverage"`
- `coverage_auditor.rb:8` — `require_relative "block_coverage"`
- `coverage_auditor.rb:9` — `require_relative "font_coverage_report"`
- `coverage_auditor.rb:10` — `require_relative "unicode_17_blocks"`

The global rule:

> NEVER use `require_relative` for internal library code. Never use
> `require` with a path to code within your own library. Use Ruby
> `autoload` instead. Define autoload entries in the **immediate
> parent namespace's file**.

This is the only `require_relative` cluster left in `lib/`.

## Files

- `lib/ucode/glyphs/real_fonts.rb` — add `autoload` entries for the
  five children (`BlockCoverage`, `CoverageAuditor`,
  `FontCoverageReport`, `Unicode17Blocks`, `Writer`, plus the
  remaining `cmap_cache`, `font_locator`, `font_coverage_report`).
- The 3 child files — remove their `require_relative` lines.

## Design

The existing `lib/ucode/glyphs/real_fonts.rb` already has autoload
entries for some classes (verified via `find lib -name "real_fonts*"`).
Just need to:

1. Add missing autoload entries for any class currently loaded via
   `require_relative`.
2. Remove every `require_relative "..."` line from the child files.

Pattern (mirror `lib/ucode/glyphs/embedded_fonts.rb`):

```ruby
module Ucode
  module Glyphs
    module RealFonts
      autoload :BlockCoverage,        "ucode/glyphs/real_fonts/block_coverage"
      autoload :CoverageAuditor,     "ucode/glyphs/real_fonts/coverage_auditor"
      autoload :FontCoverageReport,  "ucode/glyphs/real_fonts/font_coverage_report"
      autoload :Unicode17Blocks,     "ucode/glyphs/real_fonts/unicode_17_blocks"
      autoload :Writer,              "ucode/glyphs/real_fonts/writer"
      # ... preserve existing entries
    end
  end
end
```

## Acceptance

- `grep -r "require_relative" lib/` returns nothing.
- `bundle exec rspec spec/ucode/glyphs/real_fonts/` passes.
- `bundle exec ucode audit font <any.ttf>` still works (smoke check
  that autoload resolves correctly at runtime).
