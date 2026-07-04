# TODO 03 — Delete stale `BUG-code-chart-svg-transforms-have-pdf-text-matrix.md`

## Status

Pending. Audit finding (doc cleanup).

## Why

`BUG-code-chart-svg-transforms-have-pdf-text-matrix.md` (untracked,
dated 2026-07-01) describes SVG output of the form:

```xml
<g transform="scale(51.354062) translate(-12780.598814, -17391.128233)">
  <path d="..."/>
</g>
```

This does NOT match any current code path on `main`:

- `lib/ucode/glyphs/embedded_fonts/svg.rb` emits a flat `<path>` with
  no `<g>` wrapper and no transforms. Y-negation happens at emit time
  via `format_cmd` / `format_cmd_q` directly from
  `outline.to_commands`.
- The contributor's branch (`feat/code-chart-extractor`) has the SAME
  `Svg.rb` — confirmed via `git show`.
- The transform shape described matches the **retired v0.1 cell
  extractor** (composited glyph + border), which was removed in PR #59.

Keeping the BUG doc invites a future contributor to "fix" a bug that
does not exist.

## Files

- `BUG-code-chart-svg-transforms-have-pdf-text-matrix.md` — delete.

## Acceptance

- File removed from the working tree.
- `BUG-code-chart-cid-font-extraction.md` is **kept** (still
  relevant — closed by TODO 10's perf fix).
