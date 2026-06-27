# 13 — Directory emitter

## Goal

Walk an in-memory `AuditReport` (built by TODOs 06-12) and write it
to the directory tree specified in `03-directory-output-spec.md`.
Pure I/O — no audit logic, no font parsing. Idempotent via
content-hash comparison.

This is the Mode 2 output writer; equivalent in role to
`Ucode::Repo::CodepointWriter` for Mode 1.

## Files to create

```
lib/ucode/audit/emitter.rb                 # namespace hub
lib/ucode/audit/emitter/face_directory.rb  # top-level orchestrator
lib/ucode/audit/emitter/index_emitter.rb   # writes index.json
lib/ucode/audit/emitter/block_emitter.rb   # writes blocks/<NAME>.json
lib/ucode/audit/emitter/plane_emitter.rb   # writes planes/<N>.json
lib/ucode/audit/emitter/script_emitter.rb  # writes scripts/<CODE>.json
lib/ucode/audit/emitter/codepoint_emitter.rb # writes codepoints/<NAME>.json (verbose)
lib/ucode/audit/emitter/glyph_emitter.rb   # writes glyphs/U+XXXX.svg (opt-in)
lib/ucode/audit/emitter/collection_emitter.rb # writes <source>/00-<face>/ layout for TTC
lib/ucode/audit/emitter/library_emitter.rb # writes library-level index for directory mode
```

Specs under `spec/ucode/audit/emitter/`.

## Public API

```ruby
emitter = Ucode::Audit::Emitter::FaceDirectory.new(
  output_root: Pathname.new("output/font_audit"),
  verbose: false,
  with_glyphs: false,
)
emitter.emit_face(label: "Inter-Regular", report: report)
# → writes output/font_audit/Inter-Regular/index.json + blocks/ + ...

emitter.emit_collection(label: "Inter", reports: array_of_reports)
# → writes output/font_audit/Inter/00-<face>/ + 01-<face>/ + ...

emitter.emit_library(reports_by_label:)
# → writes output/font_audit/<label>/... per font + library index
```

## Idempotency rules

Per `03-directory-output-spec.md`:

- Each output file is content-hash compared against the existing file
  (if any). Same content → no write. Different content → atomic write
  (write to `.tmp`, rename).
- Skip-newer check: if the source font's mtime is older than the
  output chunk's mtime AND the baseline UCD's mtime is older too,
  skip the chunk entirely. Saves work on no-op re-runs.
- Reuse `Ucode::Repo::AtomicWrites` (existing module) for the write
  primitive. Do not reimplement.

## Emitter responsibilities

### IndexEmitter

Writes `index.json`. Serializes the `AuditReport` via lutaml-model's
`to_hash`, then:

- Drop `codepoint_details` (always — only emitted by CodepointEmitter).
- Drop `covered_codepoints` from each `block_summaries` entry (always
  — IndexEmitter is for the compact form).
- Embed `missing_codepoints` per block (per decision in `00-README.md`).
- Add the `totals` summary computed from `block_summaries`.

### BlockEmitter

Writes one file per `BlockSummary` under `blocks/<NAME>.json`. The
filename uses the block name verbatim (filesystem-safe per
`03-directory-output-spec.md` §"Block filename encoding"). Each file
contains the single `BlockSummary` serialized.

### PlaneEmitter / ScriptEmitter

Roll-up views. Same shape as `block_summaries` entries but aggregated.

### CodepointEmitter (verbose only)

For each touched block, walk all codepoints in the font's cmap that
belong to that block and produce a `CodepointDetail` per codepoint.
The detail is enriched with ucode baseline data (name, gc, script,
age) via `Ucode::Database#lookup`.

Per-block chunking keeps each file under ~1MB even for CJK Extension J
(4,298 codepoints × ~200 bytes/detail ≈ 850KB).

### GlyphEmitter (opt-in)

For each covered codepoint:

1. Look up GID in the audited font's cmap.
2. Read outline via fontisan (glyf for TrueType, CharStrings for CFF).
3. Convert to SVG, normalize viewBox.
4. Write to `glyphs/U+XXXX.svg`.

Filename pattern: `U+%04X.svg` for BMP, `U+%05X.svg` for SMP, etc.
— same convention as Mode 1's glyph output.

This is the only emitter that calls fontisan's outline reading. Lazy:
construct the font handle once per face and reuse across codepoints.

### CollectionEmitter

For a TTC/OTC input, emit one `<source>/00-<face>/` directory per
face, plus a collection-level `index.json` with face metadata
(`num_fonts_in_source`, face labels, summary rollup).

### LibraryEmitter

For directory-mode input, emit one `<label>/` per font (already
produced by FaceDirectory), plus a library-level `index.json` and
`index.html` (the latter via TODO 15).

## Acceptance

- A non-verbose audit produces `index.json`, `planes/`, `blocks/`,
  `scripts/`. No `codepoints/`. No `glyphs/`.
- A `--verbose` audit additionally produces `codepoints/<NAME>.json`
  per touched block.
- A `--with-glyphs` audit additionally produces `glyphs/U+XXXX.svg`
  per covered codepoint.
- `index.json` size is under 200KB for a 50k-codepoint CJK font (no
  per-codepoint detail inlined).
- Each `codepoints/<NAME>.json` chunk is under 1MB.
- Re-running the same audit twice produces zero file writes on the
  second run.
- Re-running after touching the source font rewrites the affected
  chunks only.
- Block filenames preserve original names verbatim (no slugifying).
- No `double()` in specs.
- Rubocop clean.

## References

- Spec: `TODO.new/03-directory-output-spec.md`
- Models: `TODO.new/07-audit-models-port.md`
- Atomic writes: `lib/ucode/repo/atomic_writes.rb` (existing)
- Mode 1 equivalent: `lib/ucode/repo/codepoint_writer.rb`
- Browser consumer: `TODO.new/14-html-face-browser.md`
