# 09 — fontist-archive-public structure: coverage/ + woff/ + unicode/ + panglyph/

## Goal

Define the canonical directory structure of `fontist-archive-public`
once all data streams are wired. Today it has `coverage/` (fontisan
audit YAMLs) + `woff/` (open-license specimens) + `fonts.json`. We
need to add `unicode/` (ucode's Unicode data) and `panglyph/` (the
universal font).

## Why a separate TODO

Three independent pipelines now feed fontist-archive-public:

1. **fontist-archive-private CI** (per-formula) → `coverage/` + `woff/`
2. **ucode CI** (per-Unicode-version) → `unicode/block-feed/` +
   `unicode/universal-glyph-set/` + `unicode/codepoints-{version}.tar.zst`
3. **panglyph CI** (per-release) → `panglyph/v{X.Y.Z}/` + `manifest.json`

Each is owned by a different repo and syncs on a different cadence.
This TODO defines how they coexist in one archive without colliding.

## Target structure

```
fontist-archive-public/
├── README.md                            # canonical index
│
├── coverage/                            # ← from fontist-archive-private CI
│   └── {formula_slug}/{PSName}.yaml     # per-face audit YAMLs
│       google/abeezee/ABeeZee-Regular.yaml
│       manual/inter/Inter-Bold.yaml
│       macos/...
│
├── woff/                                # ← from fontist-archive-private CI (open-license only)
│   └── {formula_slug}/{PSName}.woff2
│       google/abeezee/ABeeZee-Regular.woff2
│       (NO macos/ — proprietary)
│
├── fonts.json                           # font registry (canonical name → formula slugs)
├── font-metadata.json                   # per-face metadata (weight, style, etc.)
│
├── unicode/                             # ← from ucode CI (TODO.new 41)
│   ├── block-feed/                      # compact per-block Unicode data feed
│   │   ├── unicode-blocks.json
│   │   ├── unicode-version.json
│   │   └── unicode/blocks/<slug>.json
│   │
│   ├── universal-glyph-set/             # one SVG per codepoint (TODO.new 35)
│   │   ├── manifest.json                # version, counts, generatedAt
│   │   ├── entries/U+XXXX.json          # per-glyph provenance
│   │   └── glyphs/U+XXXX.svg
│   │
│   ├── codepoints-{version}.tar.zst     # per-codepoint detailed JSONs (TODO.new 41 §Phase A.3)
│   └── codepoints-index.json            # quick lookup: cp_int → {block, name, ...}
│
├── panglyph/                            # ← from panglyph CI (TODO 04)
│   ├── manifest.json                    # latest version + version index
│   └── v17.0.0/                         # per-release directory
│       ├── panglyph-unicode17.ttf
│       ├── panglyph-unicode17.woff2
│       ├── panglyph-unicode17.otf
│       ├── coverage-report.json
│       └── source-manifest.json         # OFL provenance per source font
│
├── bin/
│   ├── sync-from-private                # existing: pulls coverage/ + woff/
│   ├── sync-from-ucode                  # NEW: pulls unicode/
│   └── sync-from-panglyph               # NEW: pulls panglyph/
│
└── .github/workflows/
    ├── sync-private.yml                 # triggers on archive-private push
    ├── sync-ucode.yml                   # triggers on ucode publish workflow
    └── sync-panglyph.yml                # triggers on panglyph tag
```

## Three sync workflows

### sync-private.yml (existing — minor update)

Triggers on push to `fontist/fontist-archive-private` main.
- Clones private shallow
- Copies `coverage/` (ALL audit YAML — metadata is public)
- Copies `woff/` (open-license only — checks each formula's license)
- Updates `fonts.json` + `font-metadata.json`
- Commits + pushes to public

### sync-ucode.yml (NEW — TODO.new 41)

Triggers on workflow_run of `fontist/ucode`'s `publish-unicode-archive.yml`.
- Clones ucode's published artifacts (Release asset OR direct git push
  from ucode CI — design decision in TODO.new 41)
- Syncs `unicode/block-feed/`, `unicode/universal-glyph-set/`
- Replaces `unicode/codepoints-{version}.tar.zst`
- Updates `unicode/codepoints-index.json` (regenerated from per-cp JSONs)

### sync-panglyph.yml (NEW — TODO 04)

Triggers on tag push to `fontist/panglyph`.
- Clones panglyph Release assets
- Creates `panglyph/v{X.Y.Z}/` directory
- Updates `panglyph/manifest.json` (latest version pointer)

## Conflict resolution

The three workflows can run concurrently. They write to disjoint
directories (`coverage/`, `unicode/`, `panglyph/`), so git conflicts
are unlikely. If two syncs race, the second one's commit fails cleanly
(Git pre-receive hook rejects non-fast-forward) and re-runs on the
next trigger.

## Manifest of manifests

Top-level `archive-public/manifest.json`:

```json
{
  "updated_at": "2026-...",
  "coverage": {
    "total_formulas": 4283,
    "total_faces": 12000,
    "last_sync": "2026-..."
  },
  "woff": {
    "total_faces": 9500,
    "last_sync": "2026-..."
  },
  "unicode": {
    "ucd_version": "17.0.0",
    "block_count": 346,
    "codepoint_count": 299382,
    "universal_set_built_at": "2026-..."
  },
  "panglyph": {
    "latest": "17.0.0",
    "released_at": "2026-..."
  }
}
```

fontist.org's fetch-data.sh reads this to display "data refreshed X
hours ago" on the site.

## Acceptance

- [ ] `unicode/` directory exists with block-feed + universal-glyph-set
- [ ] `panglyph/` directory exists with at least one version
- [ ] Three sync workflows exist + run independently
- [ ] `archive-public/manifest.json` reflects the current state
- [ ] No git conflicts when 2+ syncs run concurrently (disjoint paths)
- [ ] fontist.org's fetch-data.sh can pull all four data streams

## Dependencies / blockers

- **TODO.new 41** — ucode → archive bridge (the `unicode/` sync)
- **TODO 04** — panglyph publish (the `panglyph/` sync)
- **TODO 08** — archive-private uses ucode (the `coverage/` sync content changes)

## References

- `fontist/fontist-archive-public` repo (current state)
- `fontist.org/scripts/fetch-data.sh` — consumer of all four streams
- [TODO.new 41](../TODO.new/41-ucode-unicode-archive-bridge.md) — ucode publishing
- [TODO 04](04-panglyph-publish-pipeline.md) — panglyph publishing
