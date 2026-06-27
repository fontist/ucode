# 16 — CLI audit subcommands

## Goal

Wire the audit pipeline to `bin/ucode` as a unified `ucode audit`
namespace. Replace `ucode font-coverage` (the v0.1 name). The CLI is
a thin Thor front-end; real logic lives in `Ucode::Commands::Audit::*Command`.

## Files to create

- `lib/ucode/commands/audit_font_command.rb`
- `lib/ucode/commands/audit_collection_command.rb`
- `lib/ucode/commands/audit_library_command.rb`
- `lib/ucode/commands/audit_compare_command.rb`
- `lib/ucode/commands/audit_browser_command.rb`
- Update `lib/ucode/cli.rb` to register the new `audit` namespace.

Plus specs for each command (in-process, no shell-out).

## CLI surface

### `ucode audit font PATH [options]`

Single face audit. PATH is a font file or a fontist-resolvable name
(`label=/path/to/font.ttf` for direct, bare name for fontist find).

Options:
- `--label LABEL` — output directory name (default: postscript_name or font file basename).
- `--unicode-version VERSION` — baseline version (default: ucode's default).
- `--verbose` — emit per-codepoint detail under `codepoints/`.
- `--with-glyphs` — emit per-codepoint SVG under `glyphs/` (renders from audited font).
- `--brief` — cheap-extractor-only mode.
- `--output DIR` — output root (default: `output/font_audit`).
- `--browse` — also generate the face HTML browser.
- `--format text|json|yaml` — stdout format when no `--output`.

Output: `<output>/<label>/` directory tree (per TODO 13).

### `ucode audit collection PATH [options]`

TTC/OTC/dfong. Same options as `audit font` plus:

- `--font-index N` — audit only face N (output behaves like single face).

Output: `<output>/<source_label>/00-<face>/...` per TODO 13.

### `ucode audit library DIR [options]`

Walk a directory of fonts (recursive optional).

Options:
- `--recursive` — walk into subdirectories.
- `--parallel N` — parallel face audits (default: ucode's default).
- All `audit font` options apply per-face.
- `--browse` — also generate the library HTML browser at `<output>/index.html`.

Output: per-face directories + library-level index.

### `ucode audit compare LEFT RIGHT [options]`

Diff two audits. LEFT and RIGHT each may be:

- A path to a font file (audited on-the-fly).
- A path to a saved audit directory (reads its `index.json`).
- A path to a saved `index.json` directly.

Options:
- `--format text|json` — output format.
- `--output FILE` — write to file (default: stdout).

Output: `AuditDiff` rendered via TODO 12.

### `ucode audit browser [options]`

Regenerate HTML browsers from existing JSON audits.

Options:
- `--input DIR` — audit root (default: `output/font_audit`).
- `--faces-only` — regenerate per-face `index.html` only.
- `--library-only` — regenerate library-level `index.html` only.

Output: HTML files only; no JSON rewrites.

## Rename of `ucode font-coverage`

`ucode font-coverage` is removed (not aliased) — nothing external
depends on it yet. The current `RealFonts` subsystem that powers it
becomes the `Ucode::Audit::FontLocator` + `Ucode::Audit::CoverageAuditor`
internally; the CLI surface is the new `audit` namespace.

`output/font_coverage/` directory name is renamed to
`output/font_audit/` in the same PR. Anyone with stale output from
v0.1 can delete it manually.

## Command class pattern

Each `Commands::Audit::*Command` is a pure Ruby class with a `#run`
method. No Thor knowledge inside. Thor (in `lib/ucode/cli.rb`) just
parses args and constructs the command. This pattern matches the
existing `Ucode::Commands::*Command` classes.

```ruby
module Ucode
  module Commands
    class AuditFontCommand
      def initialize(font_path, label:, unicode_version:, verbose:, with_glyphs:, brief:, output_root:, browse:)
        # ...
      end

      def run
        # Resolve font, build Context, run extractors, emit.
      end
    end
  end
end
```

## Acceptance

- All 5 commands exist and are spec'd in-process.
- `ucode audit font <fixture.ttf>` produces the directory tree at
  `output/font_audit/<label>/`.
- `ucode audit font <fixture.ttf> --browse` additionally produces
  `index.html` that opens correctly.
- `ucode audit collection <fixture.ttc>` produces one tree per face.
- `ucode audit library spec/fixtures/fonts/` audits every fixture font
  and produces a library-level index.
- `ucode audit compare` works with all three input forms (font,
  directory, json file).
- `ucode audit browser` regenerates HTML without re-auditing.
- `ucode font-coverage` is gone (verified: `bin/ucode help` does not
  list it).
- No `double()` in specs.
- Rubocop clean.

## References

- Architecture: `docs/architecture.md` §"CLI"
- Existing CLI: `lib/ucode/cli.rb`, `lib/ucode/commands/`
- All upstream TODOs: 06-15
- Removed: `ucode font-coverage` (current implementation in
  `lib/ucode/glyphs/real_fonts/` and the current CLI registration)
