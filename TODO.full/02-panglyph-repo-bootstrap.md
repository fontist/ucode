# 02 — Panglyph repo bootstrap

## Goal

Create the `fontist/panglyph` repository skeleton: gem structure, CLI
entry point, CI workflow, README. No build logic yet (that's TODO 03) —
just the scaffold that lets development proceed.

## Why a separate repo

panglyph consumes ucode's universal set as INPUT and produces a font
as OUTPUT. The assembly logic (fontisan outline extraction + font
writing + OFL packaging) is a distinct concern from ucode's Unicode
data + audit work.

Separation keeps:
- ucode focused on Unicode data + audit
- panglyph focused on font assembly
- fontisan focused on parsing + conversion primitives

## Repository structure

```
panglyph/
├── README.md                          # what panglyph is, how to build
├── LICENSE                            # OFL for the assembled font
├── CHANGELOG.md                       # version history
├── Gemfile                            # dev deps
├── panglyph.gemspec                   # gem metadata
├── lib/
│   ├── panglyph.rb                    # top-level namespace + autoloads
│   └── panglyph/
│       ├── version.rb                 # VERSION = "17.0.0"
│       ├── cli.rb                     # Thor CLI entry point
│       ├── builder.rb                 # orchestrates the full build
│       ├── outline_extractor.rb       # extracts glyf/CFF outline via fontisan
│       ├── font_assembler.rb          # assembles outlines into a font
│       ├── woff2_writer.rb            # converts TTF → WOFF2 (via fontisan)
│       ├── manifest_reader.rb         # reads ucode's universal-set manifest
│       ├── coverage_report.rb         # emits per-block source breakdown
│       └── publisher.rb               # pushes artifacts to fontist-archive-public
├── exe/
│   └── panglyph                       # CLI executable
├── spec/
│   ├── spec_helper.rb
│   └── panglyph/
│       ├── builder_spec.rb
│       ├── outline_extractor_spec.rb
│       └── ...
├── data/
│   └── OFL.txt                        # OFL license template
├── docs/
│   ├── architecture.md                # build pipeline reference
│   └── coverage-policy.md             # which fonts cover which blocks
└── .github/
    └── workflows/
        └── build.yml                  # CI: build panglyph on tag push
```

## CLI surface

```
$ panglyph --help
panglyph commands:
  panglyph build [UCD_VERSION]      # Build panglyph-unicode<version>.<ext>
  panglyph help [COMMAND]           # Describe subcommands
  panglyph manifest [UCD_VERSION]   # Print source contributions manifest
  panglyph publish [VERSION]        # Publish built artifacts to archive-public
  panglyph validate [FONT_PATH]     # Verify the built font against the universal set
  panglyph version                  # Print panglyph version
```

### `panglyph build`

```
$ panglyph build 17.0.0
→ reads ucode's universal-set manifest (must already be built)
→ for each codepoint: extracts outline from the Tier 1 source font
→ assembles outlines into a TTF in memory
→ writes panglyph-unicode17-17.0.0.ttf
→ converts to panglyph-unicode17-17.0.0.woff2
→ emits coverage-report.json (per-block source breakdown)
```

### `panglyph validate`

```
$ panglyph validate panglyph-unicode17-17.0.0.ttf
→ cmap-walks the built font
→ compares against ucode's universal-set codepoint list
→ reports: 299382 codepoints, 297415 covered (99.3%), 1967 missing
→ lists missing codepoints with their Tier 1 source (so the build can be fixed)
```

### `panglyph publish`

```
$ panglyph publish 17.0.0
→ clones fontist-archive-public (shallow)
→ copies panglyph-unicode17-17.0.0.{ttf,woff2} to archive-public/panglyph/
→ updates archive-public/panglyph/manifest.json
→ commits + pushes via GHA bot token
```

## Dependencies

```ruby
# panglyph.gemspec
spec.add_dependency "fontisan", "~> 0.3"   # font parsing + writing primitives
spec.add_dependency "ucode", "~> 0.1"      # universal-set manifest reader
spec.add_dependency "thor", "~> 1.3"       # CLI
spec.add_dependency "json", "~> 2.0"
spec.add_dependency "rubyzip", "~> 2.3"    # OFL packaging
```

fontisan needs font-WRITING primitives added (it currently only reads +
converts). TODO 03 lists what fontisan needs to expose.

## CI workflow

`.github/workflows/build.yml`:

```yaml
name: Build panglyph

on:
  push:
    tags: ['v*']
  workflow_dispatch:
    inputs:
      ucd_version:
        description: 'UCD version to build (e.g. 17.0.0)'
        required: true
        default: '17.0.0'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.4'
          bundler-cache: true
      - name: Fetch ucode universal set
        run: |
          git clone --depth 1 https://github.com/fontist/ucode ucode-repo
          cd ucode-repo && bundle exec ucode universal-set build ${{ inputs.ucd_version }}
          tar czf /tmp/universal-set.tar.gz output/universal_glyph_set/
      - name: Build panglyph
        run: |
          bundle exec panglyph build ${{ inputs.ucd_version }} \
            --universal-set=/tmp/universal-set.tar.gz
      - name: Validate
        run: bundle exec panglyph validate panglyph-unicode*.ttf
      - name: Publish to fontist-archive-public
        env:
          GH_TOKEN: ${{ secrets.ARCHIVE_PUBLIC_BOT_TOKEN }}
        run: bundle exec panglyph publish ${{ inputs.ucd_version }}
      - uses: actions/upload-artifact@v4
        with:
          name: panglyph-${{ inputs.ucd_version }}
          path: |
            panglyph-unicode17-*.ttf
            panglyph-unicode17-*.woff2
            coverage-report.json
```

## Acceptance

- [ ] `fontist/panglyph` repo exists
- [ ] README.md explains what panglyph is + how to build (per TODO 01)
- [ ] LICENSE is OFL
- [ ] `bundle exec panglyph version` prints `17.0.0`
- [ ] `bundle exec panglyph --help` lists build/manifest/publish/validate
- [ ] CI workflow file exists and is syntactically valid
- [ ] One trivial spec passes (`spec/panglyph/version_spec.rb`)
- [ ] Repo is public

## References

- [TODO 01](01-panglyph-vision.md) — vision
- [TODO 03](03-panglyph-font-builder.md) — build implementation
- [TODO.new/35](../TODO.new/35-universal-set-production-run.md) — input format
