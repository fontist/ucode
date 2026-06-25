# 04. Cache layout (XDG-compliant)

**Goal**: On-disk cache for fetched UCD sources and derived SQLite indices, with a
predictable, XDG-compliant layout. Ported from fontisan's `CacheManager` verbatim except
for path namespacing and the addition of `data/`, `pdfs/` subdirs.

**Depends on**: 03.

**Files**:
- `lib/ucode/cache.rb` — module-level API, no instances (matches fontisan pattern).
- `spec/ucode/cache_spec.rb`.

## Tasks

- [ ] Port `Fontisan::Ucd::CacheManager` → `Ucode::Cache`. Replace `fontisan/unicode`
  path segment with `ucode/unicode`. Honor `XDG_CACHE_HOME` (not `XDG_CONFIG_HOME` —
  cache, not config; this is a small fix to fontisan's choice).
- [ ] Layout per version:
  ```
  <cache_root>/<version>/
    ucd/            # extracted UCD.zip
    unihan/         # extracted Unihan.zip
    pdfs/           # per-block PDFs
    index/          # blocks.yml, scripts.yml (legacy YAML index)
    sqlite/         # ucode.sqlite3 (primary lookup)
  ```
- [ ] Methods (one concern each): `root`, `version_dir`, `ucd_dir`, `unihan_dir`,
      `pdfs_dir`, `index_dir`, `sqlite_path`, `blocks_index_path`, `scripts_index_path`,
      `cached?`, `cached_versions`, `ensure_version_dir!`, `remove_version`.
- [ ] Idempotent: `ensure_version_dir!` is safe to call repeatedly.

## Acceptance criteria

- All path methods return `Pathname`.
- `cached?("17.0.0")` returns false on a fresh cache.
- `ensure_version_dir!("17.0.0")` then `cached?("17.0.0")` returns true.
- No `File.join` with hardcoded `~/.config` anywhere outside `Cache`.

## Architectural notes

- **Pure filesystem module.** No network, no parsing. Easiest unit to test and the
  foundation everything else depends on.
- `Cache` reads `Ucode.configuration.cache_root` rather than computing paths itself, so
  tests can swap roots.
