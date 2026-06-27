# 06 — Audit namespace skeleton

## Goal

Stand up the `Ucode::Audit` namespace hub, the `Registry`, and the
`Context`. No extractors, no models, no CLI yet — just the empty
orchestrator scaffolding that subsequent TODOs (07-12) populate.

This is the foundation; everything else in the migration slots into it.

## Files to create

- `lib/ucode/audit.rb` — namespace hub. Declares the autoloads (Ruby
  autoload — see project memory `feedback_require_relative.md`).
- `lib/ucode/audit/registry.rb` — ordered list of extractor classes,
  iterated by `AuditCommand` for every face.
- `lib/ucode/audit/context.rb` — value object carrying everything an
  extractor needs to do its job (font handle, codepoint set, UCD
  baseline, options).
- `lib/ucode/audit/extractors.rb` — extractors namespace hub (empty;
  filled by TODO 08 and 09).
- `spec/ucode/audit/registry_spec.rb` — empty registry iterates zero
  extractors without error.
- `spec/ucode/audit/context_spec.rb` — context memoizes codepoints,
  baseline, source_format.

## Port from fontisan

Direct port of:
- `fontisan/lib/fontisan/audit.rb` (namespace hub pattern)
- `fontisan/lib/fontisan/audit/registry.rb` (Registry module)
- `fontisan/lib/fontisan/audit/context.rb` (Context class)
- `fontisan/lib/fontisan/audit/extractors.rb` (extractors namespace)

with namespace changes (`Fontisan::` → `Ucode::`).

## Context adjustments vs fontisan

The fontisan `Context` carries:

- `font`, `font_path`, `font_index`, `num_fonts_in_source`, `options`
- `codepoints` (memoized cmap keys)
- `ucd` (memoized UCD database + version + warning)
- `cldr` (memoized CLDR index — **drop**, see below)
- `source_format`

ucode's `Context` drops:

- `cldr` and the entire `resolve_cldr` path. CLDR is out of scope
  (decision in `TODO.new/00-README.md`).
- `Ucd::VersionResolver` calls → replace with `Ucode::VersionResolver`
  (ucode's own; see `lib/ucode/version_resolver.rb`).
- `Ucd::Database.open` / `Ucd::CacheManager` calls → replace with
  `Ucode::Database.open` and `Ucode::Cache` (ucode's own; see
  `lib/ucode/database.rb` and `lib/ucode/cache.rb`).
- `Ucd::Downloader` calls → replace with `Ucode::Fetch::UcdZip`.

ucode's `Context` adds:

- `baseline` — pre-resolved baseline struct (the assigned-codepoint
  set for the target Unicode version). Extractors read from this
  rather than re-resolving.
- `renderer` — optional glyph renderer for `--with-glyphs` mode. Set
  only when the option is on; nil otherwise. Avoids loading fontisan's
  outline reader unless needed.

## Registry adjustments

The fontisan registry has two extractor lists:

- `ORDERED_EXTRACTORS` — 12 extractors (full audit).
- `BRIEF_EXTRACTORS` — 5 extractors (cheap pass).

ucode's registry starts empty (no extractors ported yet). TODOs 08 and
09 add them in order. The brief/full mode switch ports across unchanged.

Drop the `Extractors::LanguageCoverage` entry from both lists — CLDR
out of scope.

## Acceptance

- `Ucode::Audit` constant exists; `Ucode::Audit::Registry` and
  `Ucode::Audit::Context` are referable.
- `Ucode::Audit::Registry.each(mode: :full) { |e| }` iterates zero
  extractors without error (empty list).
- `Ucode::Audit::Registry.each(mode: :brief) { |e| }` same.
- `Ucode::Audit::Context.new(font: ..., ...)` constructs and memoizes
  `codepoints` on first call.
- `Context#baseline` returns a real `Ucode::Database`-backed struct
  (or raises a clear error if the version is uncached).
- No `cldr` method exists on `Context` (verified by spec).
- All specs use real model instances; no `double()`.
- Rubocop clean.

## References

- Source: `fontisan/lib/fontisan/audit.rb`, `audit/registry.rb`,
  `audit/context.rb`, `audit/extractors.rb`
- ucode UCD infra: `lib/ucode/database.rb`, `lib/ucode/cache.rb`,
  `lib/ucode/version_resolver.rb`, `lib/ucode/fetch/`
- Project memory: `feedback_require_relative.md` (autoload rule),
  `feedback_use_fontist_only.md`
- Follow-ups: `TODO.new/07-audit-models-port.md`,
  `TODO.new/08-extractors-cheap-port.md`,
  `TODO.new/09-extractors-expensive-port.md`
