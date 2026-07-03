# TODO 10 — essenfont integration (cross-repo guide)

## Status

Pending. Depends on ucode TODOs 01-08 being merged and released.

## Context

This TODO is a **guide for the essenfont repo**, not code in ucode.
Once ucode ships `Ucode::Unicode`, essenfont should delete its
duplicated `Plane`, `Block`, `BlockCatalog`, and hardcoded
`UNICODE_17_ASSIGNED` constant, replacing them with the ucode API.

## Files to delete in essenfont

- `lib/essenfont/otc/plane.rb` (~40 lines)
- `lib/essenfont/otc/block_catalog.rb` (~50 lines)
- `lib/essenfont/otc/plane_catalog.rb` (~10 lines, if separate)
- `spec/essenfont/otc/plane_spec.rb` (~40 lines)
- `spec/essenfont/otc/block_catalog_spec.rb` (~40 lines)

**Total: ~180 lines deleted.**

## Migration

### Before (essenfont current code)

```ruby
# lib/essenfont/otc/plane.rb
class Essenfont::Otc::Plane
  NAMES = { 0 => :BMP, 1 => :SMP, 2 => :SIP, 3 => :TIP, 14 => :SSP }.freeze
  # ... 40 lines of Plane logic
end

# scripts/emit_coverage_manifest.rb
UNICODE_17_ASSIGNED = 159_866  # hardcoded — drifts!
```

### After (using ucode API)

```ruby
# Add ucode to essenfont's Gemfile:
# gem "ucode", "~> 0.3"

# In essenfont code:
require "ucode"

# Plane lookup
plane = Ucode::Unicode.for_version("17.0").find_plane_by_codepoint(0x4E00)
plane.short_name  # => :BMP

# Block lookup
block = Ucode::Unicode.for_version("17.0").find_block_by_codepoint(0x4E00)
block.id  # => "CJK_Unified_Ideographs"

# Assigned count (no more hardcoding)
assigned = Ucode::Unicode.for_version("17.0").assigned_count  # => 159_866

# Coverage manifest
coverage_pct = (total_cps.to_f / assigned * 100).round(2)
```

### essenfont's `Plane` alias (optional compatibility shim)

If essenfont wants to minimize its diff:

```ruby
module Essenfont
  module Otc
    Plane = Ucode::Unicode::Plane  # alias
  end
end
```

Then `Essenfont::Otc::Plane` still works, just points at ucode's
implementation. Delete the alias in a follow-up cleanup.

## Version selection

essenfont audits fonts that target specific Unicode versions. The
font's `unicode_version` field (e.g., `"16.0"`) drives the Catalog:

```ruby
def coverage_report(font)
  catalog = Ucode::Unicode.for_version(font.unicode_version)
  total_assigned = catalog.assigned_count
  covered = font.codepoints.count { |cp| catalog.find_block_by_codepoint(cp) }
  {
    unicode_version: catalog.version,
    total_assigned: total_assigned,
    covered: covered,
    coverage_percent: (covered.to_f / total_assigned * 100).round(2),
  }
end
```

## Acceptance criteria (essenfont side)

- `bundle exec rspec` passes with ucode API replacing local Plane/Block
- `scripts/emit_coverage_manifest.rb` uses `Ucode.ASSIGNED_COUNT` (or version-specific)
- No hardcoded Unicode version constants remain
- `ucode` gem version pinned in essenfont's Gemfile
