# 36. fontisan migration — audit, shim, cutover

**Goal**: Migrate fontisan to depend on ucode for all UCD functionality. Remove
fontisan's UCD code after a one-cycle deprecation window.

**Depends on**: 26–28, 35.

**Files** (in fontisan repo):
- `fontisan.gemspec` — add `spec.add_dependency "ucode", "~> 0.1"`.
- `lib/fontisan/ucd.rb` — becomes a thin compatibility shim. Each autoloaded constant is
  aliased to the corresponding `Ucode::*` constant. Deprecation warning on first access.
- `lib/fontisan/audit/context.rb` — switch from `Ucd::Index.load` to
  `Ucode::Index.load`; remove the UCDXML-only paths.
- `lib/fontisan/cli/ucd_cli.rb` — either delete (delegate to `ucode` CLI) or wrap
  `Ucode::Cli` with thin Thor pass-through.
- `lib/fontisan/models/ucd.rb` + `lib/fontisan/models/ucd/` — **delete entirely**
  (ucdxml is no longer parsed).
- `lib/fontisan/ucd/cache_manager.rb` → **delete** (use `Ucode::Cache`).
- `lib/fontisan/ucd/version_resolver.rb` → **delete** (use `Ucode::VersionResolver`).
- `lib/fontisan/ucd/downloader.rb` → **delete** (use `Ucode::Fetch::*`).
- `lib/fontisan/ucd/database.rb`, `db_builder.rb`, `index_builder.rb`, `index.rb`,
  `range_entry.rb`, `aggregator.rb`, `config.rb`, and the four error files → **delete**.
- All corresponding spec files → delete or rewrite against `Ucode::*`.

## Tasks

- [ ] **Phase A — audit**:
  - Map every public symbol fontisan exposes under `Fontisan::Ucd::*` and
    `Fontisan::Models::Ucd::*` to its `Ucode::*` counterpart.
  - Confirm there are no external callers (fontisan is the only consumer — verify by
    grepping the fontist org repos for `Fontisan::Ucd`).
  - Document any API surface ucode is missing; add it to ucode first.
- [ ] **Phase B — add dependency**:
  - `fontisan.gemspec` depends on `ucode`.
  - Add the compat shim `lib/fontisan/ucd.rb` that aliases constants:
    ```ruby
    module Fontisan
      module Ucd
        autoload :CacheManager, "fontisan/ucd/cache_manager"  # shim file
        # ...
      end
    end

    # In each shim file:
    module Fontisan::Ucd::CacheManager
      def self.root = Ucode::Cache.root
      # ... delegate every method
      extend self
    end
    ```
  - Each shim method emits a `DeprecationWarning` on first call.
- [ ] **Phase C — migrate callers**:
  - `audit/context.rb`: replace `Ucd::Index.load` → `Ucode::Index.load`. Replace
    `Ucd::CacheManager.blocks_index_path` → `Ucode::Cache.blocks_index_path`.
  - `cli/ucd_cli.rb`: delegate to `Ucode::Cli` (or remove).
- [ ] **Phase D — remove deprecated code**:
  - Delete `lib/fontisan/ucd/`, `lib/fontisan/models/ucd.rb`,
    `lib/fontisan/models/ucd/`, `lib/fontisan/cli/ucd_cli.rb`, the shim file, and
    corresponding specs.
  - Update fontisan's CLAUDE.md to remove the UCD section.

## Acceptance criteria

- After Phase C, fontisan's spec suite passes against ucode.
- `bundle exec fontisan ucd download` still works (via Ucode::Cli under the hood, or
  removed if ucode's CLI is sufficient).
- fontisan's `audit` command produces identical output before and after migration.
- After Phase D, no `Fontisan::Ucd` or `Fontisan::Models::Ucd` constants remain.

## Architectural notes

- **Why a shim, not a hard cutover**: external consumers (other fontist org gems,
  downstream users) may call `Fontisan::Ucd::*` directly. The shim gives them a
  deprecation cycle to migrate.
- **Why delete fontisan's ucdxml model entirely**: ucdxml is the wrong source (per
  project decision). Carrying it forward perpetuates the problem.
- **API parity verification**: Phase A's audit MUST confirm ucode covers every public
  symbol fontisan exposes. If gaps exist, fix ucode first, don't paper over in the shim.

## Risks

- **Behavior drift**: fontisan's ucdxml-derived `Index` may have minor differences from
  ucode's text-file-derived `Index` (e.g., slightly different block boundaries in edge
  cases). Run fontisan's full audit suite before and after migration; diff the output.
- **Performance regression**: SQLite built from text files may be slower than from XML.
  Benchmark both; acceptable threshold: ≤ 2× XML build time (text-file parsers do more
  work).