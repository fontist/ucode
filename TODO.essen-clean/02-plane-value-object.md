# TODO 02 — `Ucode::Unicode::Plane` value object

## Status

Pending. Depends on TODO 01.

## Context

A Unicode plane is a contiguous range of 65,536 codepoints. There are
17 planes (0–16). Only 5 have common short names (BMP, SMP, SIP, TIP,
SSP); the rest have descriptive names from
`PropertyValueAliases.txt`.

This is a **pure value object** — it carries data, nothing else. It is
NOT a lutaml-model (those are serialization DTOs). Different concern,
different seam.

## Files

- `lib/ucode/unicode/plane.rb` (NEW)

## Design

```ruby
module Ucode
  module Unicode
    Plane = Struct.new(
      :number,        # Integer 0..16
      :range,         # Range<Integer> e.g. (0x0000..0xFFFF)
      :short_name,    # Symbol or nil — :BMP, :SMP, :SIP, :TIP, :SSP, :SPUA_A, :SPUA_B
      :display_name,  # String — "Basic Multilingual Plane"
      :assigned_count,# Integer — assigned codepoints in this plane (version-specific)
      keyword_init: true,
    ) do
      def cover?(codepoint)
        range.cover?(codepoint)
      end

      def block_count
        nil # filled by Catalog — Plane itself doesn't know block list
      end

      def freeze
        range.freeze
        super
      end
    end
  end
end
```

## Plane name mapping (from PropertyValueAliases.txt)

| Number | Short name | Display name                         |
|--------|------------|--------------------------------------|
| 0      | :BMP       | "Basic Multilingual Plane"           |
| 1      | :SMP       | "Supplementary Multilingual Plane"   |
| 2      | :SIP       | "Supplementary Ideographic Plane"    |
| 3      | :TIP       | "Tertiary Ideographic Plane"         |
| 4–13   | nil        | "Plane 4" .. "Plane 13" (unassigned) |
| 14     | :SSP       | "Supplementary Special-purpose Plane"|
| 15     | :SPUA_A    | "Supplementary Private Use Area-A"   |
| 16     | :SPUA_B    | "Supplementary Private Use Area-B"   |

## Immutability

Planes are constructed frozen by the Catalog. The `freeze` override
ensures the `range` is also frozen (Ranges are not frozen by default
in Ruby < 3.0).

## Acceptance criteria

- `Plane.new(number: 0, range: 0..0xFFFF, ...).cover?(0x0041)` returns true
- Plane struct is frozen after construction
- All 17 plane names covered
- No `require_relative` — autoload from `lib/ucode/unicode.rb`
