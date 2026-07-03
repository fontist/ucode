# TODO 04 — `Ucode::Unicode::Catalog` (version-specific query)

## Status

Pending. Depends on TODOs 01, 02, 03.

## Context

The Catalog is the **single query interface** for Unicode metadata.
It is constructed with a version string and provides O(1) lookups
for planes, blocks, and assigned counts. Consumers never touch raw
metadata modules — they go through the Catalog.

This is a **deep module**: small interface (8 methods), large
implementation (loads + indexes ~346 blocks + 17 planes + counts).
The interface is the test surface.

## Files

- `lib/ucode/unicode/catalog.rb` (NEW)

## API

```ruby
module Ucode
  module Unicode
    class Catalog
      # @param version [String] full version, e.g. "17.0.0"
      # @raise [UnknownUnicodeVersionError] if metadata module missing
      def initialize(version:)
        # loads Metadata::V17_0_0 (or whichever) via autoload
        # builds frozen Arrays + Hashes for O(1) lookup
      end

      # @return [String] e.g. "17.0.0"
      def version; end

      # @return [Integer] total assigned codepoints (GC ≠ Cn, Co, Cs)
      def assigned_count; end

      # @param plane_number [Integer] 0..16
      # @return [Integer] assigned codepoints in that plane
      def assigned_in_plane(plane_number); end

      # @param plane_number [Integer]
      # @return [Plane, nil]
      def find_plane(plane_number); end

      # @param codepoint [Integer]
      # @return [Plane]
      def find_plane_by_codepoint(codepoint); end

      # @param block_id [String] e.g. "Basic_Latin"
      # @return [Block, nil]
      def find_block(block_id); end

      # @param codepoint [Integer]
      # @return [Block, nil]
      def find_block_by_codepoint(codepoint); end

      # @param plane_number [Integer]
      # @return [Array<Block>] all blocks in the plane, sorted by first_cp
      def blocks_in_plane(plane_number); end

      # @return [Array<Block>] all blocks in this Unicode version
      def all_blocks; end

      # @return [Array<Plane>] all 17 planes
      def all_planes; end
    end
  end
end
```

## Internal indexing

At construction time, the Catalog builds these frozen structures from
the metadata module:

```ruby
# Frozen at construction; never mutated
@planes_by_number   # {0 => Plane, 1 => Plane, ...} (Hash, 17 entries)
@blocks_by_id       # {"Basic_Latin" => Block, ...} (Hash, ~346 entries)
@blocks_by_plane    # {0 => [Block, Block, ...], ...} (Hash of Arrays)
@block_ranges       # sorted Array of [first_cp, last_cp, Block] for bsearch
```

`find_block_by_codepoint` uses bsearch on `@block_ranges` — O(log N).

## Thread safety

All internal structures are frozen at construction. No mutation after
`initialize`. Thread-safe by default. No locks needed.

## Relationship to `Ucode::Database`

`Ucode::Database` is the SQLite-backed UCD lookup (for full codepoint
properties). `Ucode::Unicode::Catalog` is the **static metadata** layer
(plane/block/counts). They serve different consumers:

- Catalog: fast, frozen, no SQLite dependency, ships with the gem
- Database: full per-codepoint properties, requires `ucode db build`

The Catalog does NOT depend on the Database.

## Acceptance criteria

- `Catalog.new(version: "17.0.0").assigned_count` returns the correct count
- `Catalog.new(version: "16.0.0").assigned_count` returns a DIFFERENT count (version-specific)
- `find_block("Basic_Latin")` returns a Block with `first_cp: 0`
- `find_block_by_codepoint(0x0041)` returns the Basic Latin block
- `find_plane_by_codepoint(0x1F600)` returns plane 1 (SMP)
- `blocks_in_plane(2)` returns CJK blocks sorted by first_cp
- All lookups are O(1) or O(log N)
- No `require_relative` — autoload from `lib/ucode/unicode.rb`
