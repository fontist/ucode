# 27. SQLite Database + DbBuilder

**Goal**: Port fontisan's `Database` and `DbBuilder`. The SQLite-backed production lookup.
Replace the XML parser entry point with ucode's text-file parsers (via Coordinator).

**Depends on**: 04, 25, 26.

**Files**:
- `lib/ucode/database.rb`
- `lib/ucode/db_builder.rb`
- `lib/ucode/index_builder.rb` — translates a stream of CodePoint records into sorted,
  coalesced RangeEntry arrays per property (blocks, scripts, and optionally general
  category, age, etc. for richer queries).
- Specs.

## Tasks

- [ ] Port `Fontisan::Ucd::Database` → `Ucode::Database`. API preserved:
  - `Database.open(version)` — opens existing SQLite
  - `Database.build(version)` — builds from parsed CodePoints
  - `Database.cached?(version)`
  - `lookup_block(codepoint)`, `lookup_script(codepoint)`
  - `each_block_overlapping(first, last)`, `each_script_overlapping(first, last)`
  - `block_entries`, `script_entries` — for specs
  - `close`
- [ ] Port `DbBuilder` → `Ucode::DbBuilder`. Key change: instead of
      `Models::Ucd::Ucd.from_xml(xml_path)`, build via:
  ```ruby
  def build(version)
    ucd_dir = Cache.ucd_dir(version)
    unihan_dir = Cache.unihan_dir(version)
    builder = IndexBuilder.new
    Ucode::Coordinator.new(config).tap do |c|
      c.sink { |cp| builder.add(cp) }
      c.build(ucd_dir: ucd_dir, unihan_dir: unihan_dir)
    end
    write_db(version, builder.blocks_index, builder.scripts_index)
  end
  ```
- [ ] `IndexBuilder` is incremental: receives a stream of CodePoints and accumulates
  sorted, coalesced per-property ranges. Public:
  - `add(codepoint)` — fold into blocks/scripts/property X accumulators
  - `blocks_index`, `scripts_index` — finalized Index instances after stream ends
- [ ] Add SQLite schema bump (SCHEMA_VERSION = "2") if we add new tables. For now keep
      blocks + scripts to match fontisan's interface.
- [ ] Tests build a tiny version of the DB from the fixture, then query it.

## Acceptance criteria

- `Database.build("17.0.0")` produces `ucode.sqlite3` under `Cache.sqlite_path("17.0.0")`.
- `Database.open("17.0.0").lookup_block(65)` returns `"Basic Latin"`.
- `Database.open("17.0.0").lookup_script(65)` returns `"Latin"`.
- `Database.open("17.0.0").each_block_overlapping(0, 1000).to_a` returns the right ranges.

## Architectural notes

- **Coordinator streams into IndexBuilder**: never holds all CodePoints in memory. Peak
  memory is the in-progress bsearch index plus the current CodePoint.
- **Why we don't rebuild from XML**: that was fontisan's path because fontisan had no
  text-file parsers. ucode does, so we go through Coordinator.
- **Schema versioning**: bump `SCHEMA_VERSION` if columns change. `Database.open` checks
  schema_version on open and raises `Ucode::DatabaseMissingError` (or a new
  `Ucode::DatabaseSchemaError`) if it doesn't match.