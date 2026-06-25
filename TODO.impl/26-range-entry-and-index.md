# 26. RangeEntry + Index (bsearch lookup, YAML-backed)

**Goal**: Port fontisan's `RangeEntry` and `Index` verbatim into ucode. The YAML-backed
fast lookup table; alternative to SQLite for environments without the sqlite3 gem.

**Depends on**: 04.

**Files**:
- `lib/ucode/range_entry.rb` — value object `(first_cp, last_cp, name)`. Includes
  `to_h` for YAML serialization (this is a leaf value object, not a model — YAML-serializable
  Hash is fine here, not a violation of the no-to_h rule which applies to model classes).
- `lib/ucode/index.rb` — `Index` class.
- Specs.

## Tasks

- [ ] Port `Fontisan::Ucd::RangeEntry` → `Ucode::RangeEntry`. Public attributes:
      `first_cp`, `last_cp`, `name`. Method `to_h` returning `{ first_cp:, last_cp:, name: }`.
- [ ] Port `Fontisan::Ucd::Index` → `Ucode::Index`. Public API:
  - `initialize(entries)` — sorts and stores
  - `attr_reader :entries`
  - `each`, `size`, `lookup(codepoint)`, `each_overlapping(first, last)`
  - `save(path)`, `Index.load(path)`
  - `Index.from_triples(triples)`
- [ ] Implementation detail: bsearch on sorted entries. Same as fontisan's.

## Acceptance criteria

- `Index.from_triples([[0, 127, "ASCII"], [128, 255, "Latin-1 Supplement"]]).lookup(65)`
  returns `"ASCII"`.
- Save + load round-trips an Index.
- `each_overlapping(0, 200)` yields both entries above.

## Architectural notes

- **Why keep the YAML Index AND the SQLite Database**: fontisan's `Database` (SQLite) is
  faster for production; `Index` (YAML) is simpler and dependency-free. Both serve the
  same query API. Consumers pick.
- RangeEntry's `to_h` is acceptable because it's a leaf value object, not a `Serializable`
  model. The "no `to_h`" rule applies to lutaml-model classes.