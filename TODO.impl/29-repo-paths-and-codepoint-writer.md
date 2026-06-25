# 29. Repo — paths + per-codepoint JSON writer

**Goal**: Write `output/blocks/<ID>/<U+XXXX>/index.json` for every codepoint. Streaming,
threaded, idempotent.

**Depends on**: 09–16, 25.

**Files**:
- `lib/ucode/repo.rb` — namespace hub.
- `lib/ucode/repo/paths.rb` — pure functions: `block_dir(output, block_id)`,
  `codepoint_dir(output, block_id, cp_id)`, `codepoint_json_path(...)`,
  `codepoint_glyph_path(...)`.
- `lib/ucode/repo/codepoint_writer.rb` — `write(codepoint)` and `write_each(enum)`.
- Specs.

## Tasks

- [ ] `Paths` module:
  - All methods are pure functions of `(output_root, ...)`. No I/O.
  - Block folder name = `block_id` verbatim (`ASCII`, `CJK_Ext_A`, etc.).
  - Codepoint folder name = `cp_id` (`U+0041`, `U+1F600`, `U+E0001`).
- [ ] `CodepointWriter`:
  - `initialize(output_root, parallel_workers: 8)` — owns a thread pool.
  - `write(codepoint)` — synchronous single write. For tests.
  - `write_each(enum)` — drains an Enumerator through the pool. Returns total count.
  - Per-write: serialize via `codepoint.to_hash`, write atomically (write to `.tmp`,
    rename). Skip if existing file's content matches (idempotency via hash compare, not
    mtime — safer).
- [ ] `output/blocks/<ID>/<U+XXXX>/index.json` is the output path. The glyph SVG is
      written by TODO 33's GlyphWriter to the same directory (`glyph.svg`).

## Acceptance criteria

- After running `CodepointWriter.new("/tmp/out").write(cp)` for cp=U+0041, the file
  `/tmp/out/blocks/ASCII/U+0041/index.json` exists and parses as JSON.
- Re-running `write(cp)` does not rewrite the file if content is identical (assert via
  `File.mtime` unchanged).
- `write_each` processes 10 000 fixture codepoints in under 10 s.

## Architectural notes

- **Path conventions in one place**: `Paths` is the only code that knows the on-disk
  layout. Site generator, CLI, and fontisan adapter all go through `Paths`.
- **Atomic writes**: write to `.tmp`, rename. Prevents partial files on crash.
- **Content-based idempotency**: hash the new content, compare to existing file's hash.
  Skips writes when nothing changed. Essential for re-running on the full 160 k dataset.