# TODO.full — Master plan: panglyph + ucode release + fontisan cleanup + full pipeline

This is the **shipping plan** for the full Fontist Unicode 17 stack:

1. **ucode** — Unicode data + audit tool + universal glyph set (SVGs)
2. **panglyph** (NEW) — assembles ucode's universal set into a single redistributable font
3. **fontisan** — slim font parsing + WOFF conversion library (audit + UCD removed)
4. **fontist-archive-private** — CI matrix runs ucode audit + fontisan convert per formula
5. **fontist-archive-public** — public artifacts: `coverage/` + `woff/` + `unicode/` + `panglyph/`
6. **fontist.org** — per-font unicode browser using WOFF (open-license) + ucode audit (all)

The plan below covers everything that remains after TODO.new/ (which built the
infrastructure). TODO.full/ is about wiring it all into a shippable product.

## Directives from user

- **D0** — Define + build "Fontist universal glyph set for Unicode 17" as a
  single font, in a new repo `panglyph`. Uses fontisan to extract outlines
  from source fonts, assembles into one redistributable font file.
- **D1** — Publish ucode as a patch release (0.1.0 → 0.1.1).
- **D2** — Clean up fontisan: remove `AuditCommand` and UCD/UCDXML
  subsystems (now in ucode). Keep: font parsing primitives, ConvertCommand.
- **D3** — Wire `fontist-archive-private` to use fontisan (WOFF) + ucode
  (audit) for ALL fonts. Wire `fontist-archive-public` to host all artifacts.
- **D4** — Update fontist.org to consume fontist-archive-public: render
  per-font glyphs from WOFF (open-license), show per-font coverage from
  ucode audit (all fonts).

## File index

### Foundation

- [01 — Panglyph vision: what the universal font is, why it exists](01-panglyph-vision.md)
- [02 — Panglyph repo bootstrap (gem skeleton, CLI, CI)](02-panglyph-repo-bootstrap.md)
- [03 — Panglyph font builder (outline extract + assemble + write)](03-panglyph-font-builder.md)
- [04 — Panglyph publish pipeline (release artifacts to fontist-archive-public)](04-panglyph-publish-pipeline.md)

### Releases

- [05 — ucode 0.1.1 patch release](05-ucode-0-1-1-release.md)

### Cleanup

- [06 — fontisan: remove AuditCommand (and audit/ namespace)](06-fontisan-remove-audit.md)
- [07 — fontisan: remove UCD/UCDXML subsystem](07-fontisan-remove-ucd.md)

### Pipeline

- [08 — fontist-archive-private bin/build uses ucode audit + fontisan convert](08-archive-private-bin-build.md)
- [09 — fontist-archive-public structure: unicode/ + panglyph/ + coverage/ + woff/](09-archive-public-structure.md)

### Consumer

- [10 — fontist.org: per-font WOFF glyph rendering (open-license)](10-fontist-org-woff-glyphs.md)
- [11 — fontist.org: per-font ucode audit rendering (ALL fonts)](11-fontist-org-audit-coverage.md)

### Sequencing

- [12 — Implementation order (all directives)](12-implementation-order.md)

## Critical path (high-level)

```
                ┌──────────────────────────────────┐
                │  05 ucode 0.1.1 patch release    │  ← unblocks all downstream
                └──────────────┬───────────────────┘
                               │
                ┌──────────────┴───────────────────┐
                │                                  │
                ▼                                  ▼
   ┌────────────────────────┐         ┌────────────────────────┐
   │  06 fontisan audit     │         │  01–04 panglyph        │
   │     removal            │         │     (new repo)         │
   │  07 fontisan UCD       │         └────────────┬───────────┘
   │     removal            │                      │
   └────────────┬───────────┘                      │
                │                                  │
                ▼                                  │
   ┌────────────────────────┐                      │
   │  08 archive-private    │                      │
   │     bin/build refactor │                      │
   └────────────┬───────────┘                      │
                │                                  │
                ▼                                  ▼
   ┌────────────────────────┐         ┌────────────────────────┐
   │  09 archive-public     │◄────────┤  04 panglyph publish   │
   │     structure          │         │     to archive-public  │
   └────────────┬───────────┘         └────────────────────────┘
                │
                ▼
   ┌────────────────────────┐
   │  10 fontist.org WOFF   │
   │  11 fontist.org audit  │
   └────────────────────────┘
```

## Repositories involved

| Repo | Role | Branch / state |
|---|---|---|
| `fontist/ucode` | Unicode data + audit tool + universal glyph set | `fix/fontist-consumer-canonical-path` (PR #43) |
| `fontist/panglyph` (NEW) | Universal font assembler | not yet created |
| `fontist/fontisan` | Font parser + WOFF converter | `fix/ucdxml-real-shape-parsing` (cleanup target) |
| `fontist/fontist-archive-private` | CI build env (per-formula) | main (uses old fontisan AuditCommand) |
| `fontist/fontist-archive-public` | Public artifacts | main (no unicode/ or panglyph/ yet) |
| `fontist/fontist.github.io` | Consumer site | `fix/unicode-char-page-fields` (PR #45) |

## Conventions

- **PR-per-TODO** unless tightly coupled.
- **Merging requires explicit user authorization per PR.**
- **Never push tags directly.** Tag + `rake release` only after explicit user sign-off.
- **No AI attribution** in commits, PRs, or release notes.
- **Original block names verbatim** (`CJK_Ext_A`, never slugified) in source data.
- **Vector-only glyph extraction.** No OCR.
- Branch naming: `<repo-scope>/<track-slug>` (e.g. `audit/remove-audit-command`).
