# TODO 03 — `Ucode::Unicode::Block` value object

## Status

Pending. Depends on TODO 01.

## Context

A Unicode block is a contiguous range of codepoints with a name.
There are ~346 blocks in Unicode 17.0.0. Block names use underscores
(e.g., `"Basic_Latin"`, `"CJK_Ext_A"`, `"Greek_And_Coptic"`) per the
project's "original block names verbatim" rule — never slugified.

This is a **pure value object** like Plane — carries data, not a
lutaml-model.

## Files

- `lib/ucode/unicode/block.rb` (NEW)

## Design

```ruby
module Ucode
  module Unicode
    Block = Struct.new(
      :id,            # String — "Basic_Latin", "CJK_Ext_A" (underscore form)
      :name,          # String — "Basic Latin" (original from Blocks.txt)
      :first_cp,      # Integer
      :last_cp,       # Integer
      :plane_number,  # Integer — derived: first_cp >> 16
      keyword_init: true,
    ) do
      def range
        (first_cp..last_cp)
      end

      def cover?(codepoint)
        range.cover?(codepoint)
      end
    end
  end
end
```

## Block ID vs. name

| Field  | Source             | Example              | Use                      |
|--------|--------------------|---------------------|--------------------------|
| `id`   | Blocks.txt, spaces→underscores | `"Basic_Latin"` | Filesystem paths, JSON keys |
| `name` | Blocks.txt verbatim | `"Basic Latin"`    | Display, matching original |

The `id` is the canonical key for lookups. The `name` preserves the
original Unicode spelling for display.

## `plane_number` derivation

`plane_number = first_cp >> 16`. Always derivable from `first_cp` —
not stored redundantly in metadata. The Struct field exists for
convenience but is computed at construction time by the Catalog.

## Acceptance criteria

- `Block.new(id: "Basic_Latin", name: "Basic Latin", first_cp: 0, last_cp: 0x7F, plane_number: 0).cover?(0x41)` returns true
- Block struct accepts both `id` (underscore) and `name` (display) forms
- No `require_relative` — autoload from `lib/ucode/unicode.rb`
