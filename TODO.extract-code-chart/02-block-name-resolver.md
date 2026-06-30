# TODO 02 — Block name resolver

## Status

Pending. Depends on nothing.

## Goal

Add a class method `Ucode::Parsers::Blocks.find_by_name(name)` that
resolves a Unicode block identifier (e.g. `"Sidetic"`,
`"Egyptian_Hieroglyphs_Extended-B"`) to the `Ucode::Models::Block`
instance in a given version's cached `Blocks.txt`.

This is the CLI ergonomics glue: the REQ's `ucode code-chart extract
--block Sidetic` flow takes a human-readable name and needs to know
the block's range to know which `U+XXXX` codepoints to iterate.

## Files

- `lib/ucode/parsers/blocks.rb` — add `Blocks.find_by_name(path, name)`.
- `spec/ucode/parsers/blocks_spec.rb` — cover name lookup, missing-name,
  case-sensitivity.

## Design

### Method shape

```ruby
# @param path [Pathname, String] path to a Blocks.txt
# @param name [String] block identifier (matches Models::Block#id)
# @return [Models::Block, nil] nil when no block matches
def find_by_name(path, name)
```

Returns nil for "not found" — callers (CLI, Extractor) decide whether
to raise. This matches `Models::Block` consumers that already expect
nilable lookups.

### Name matching rule

`Blocks.txt` uses `name` with whitespace collapsed to underscores
into `id`. `find_by_name` matches against `id` (the underscored
form). The REQ's example `--block Sidetic` shows that the caller
provides the underscored form already. This is consistent with the
existing `Parsers::Blocks` build logic (`name.gsub(/\s+/, "_")`).

### Why a separate method

`each_record` streams every block — the caller doesn't want to walk
~340 blocks for every name lookup. `find_by_name` short-circuits on
first match.

## Acceptance

- `find_by_name(path, "Basic_Latin")` returns the Basic Latin block.
- `find_by_name(path, "Nonexistent")` returns nil.
- Streaming still works for callers that need every block.

## Out of scope

- Fuzzy matching — exact match only. Callers validate the user's
  input against `Parsers::Blocks.each_record(path).map(&:id)` to
  surface "did you mean …?" suggestions if we ever want that; for
  now, a clean `UnknownBlockError` at the call site is enough.
- Database-backed lookup — `Ucode::Database#block_ranges_by_name` is
  a different concern (full UCD index). `find_by_name` operates on
  the cached `Blocks.txt` directly because the CodeChart extractor
  is meant to be runnable without a built database.