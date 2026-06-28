# 08 — fontist-archive-private bin/build uses ucode audit + fontisan convert

## Goal

Refactor `fontist-archive-private/bin/build` so it:

1. Calls `ucode audit font` (instead of the dead `Fontisan::Commands::AuditCommand`)
   for every matched font face.
2. Calls `fontisan ConvertCommand` (unchanged) for WOFF specimen
   generation (open-license only).
3. Drops the UCD-stub hack (lines 13-21) — ucode has its own UCD.

Pairs with TODO.new/40 (same refactor). This file is the production
checklist + acceptance criteria.

## Why now

- TODO 06 + TODO 07 land together, removing fontisan's audit + UCD.
- bin/build currently `require "fontisan"` and references
  `Fontisan::Commands::AuditCommand` — will break loudly after 0.3.0.
- The UCD stub hack returns empty aggregations — every audit YAML
  currently has `blocks: []`, `unicode_scripts: []`. Consumers see
  per-font cmap but no per-block fill ratios.

## Scope

### Phase A — Swap audit invocation

1. **Replace the audit call** (lines ~100-115 of `bin/build`):

   ```ruby
   # OLD (broken — uses removed AuditCommand + UCD stub hack)
   cmd = Fontisan::Commands::AuditCommand.new(
     face_path, font_index: font_index, no_codepoints: false
   )
   report = cmd.run
   report = report.is_a?(Array) ? report.first : report
   File.write(audit_path, report.to_yaml)
   ```

   with:

   ```ruby
   # NEW — shell out to ucode (decouples bin/build from ucode's internal API)
   args = ["ucode", "audit", "font", face_path,
           "--font-index", font_index.to_s,
           "--output", audit_path]
   args += ["--reference-universal-set", universal_set_path] if universal_set_path
   success = system(*args,
                     out: verbose ? $stdout : File::NULL,
                     err: verbose ? $stderr : File::NULL)
   warn "WARN audit #{slug}: ucode exited #{$?.exitstatus}" if verbose && !success
   ```

2. **Keep the WOFF call** (lines ~125-140) — `fontisan ConvertCommand`
   stays as-is.

3. **Remove the UCD stub hack** (lines 13-21 of `bin/build`):

   ```ruby
   # DELETE THIS:
   module Fontisan
     module Audit
       class Context
         def ucd
           @ucd ||= { version: nil, blocks_index: nil, scripts_index: nil,
                      warning: "ucd_skipped" }
         end
       end
     end
   end
   ```

4. **Update Gemfile**:

   ```ruby
   # fontist-archive-private/Gemfile
   source "https://rubygems.org"
   gem "ucode", "~> 0.1"          # NEW (audit tool)
   gem "fontisan", "~> 0.3"       # BUMPED (audit + UCD removed)
   gem "excavate"                 # unchanged (archive extraction)
   gem "rake"                     # dev
   ```

### Phase B — Universal-set reference (after TODO.new 35)

5. Once the universal glyph set is published (TODO.new 35 + TODO.new 41),
   pass `--reference-universal-set=<path>` so audits include per-block
   coverage comparison against the canonical glyphs.

6. The universal set lives in `fontist-archive-public/unicode/universal-glyph-set/`.
   bin/build checks it out shallow before invoking audits:

   ```ruby
   # Pseudocode — runs once per CI workflow, not per formula
   universal_set_path = sync_universal_set_from_public_archive
   ```

### Phase C — CI workflow updates

7. `.github/workflows/build.yml`:
   - Bump fontisan gem to 0.3.0+
   - Add ucode gem (0.1.1+) install step
   - Add a pre-step that fetches the universal set from
     `fontist-archive-public/unicode/universal-glyph-set/`
   - Otherwise matrix unchanged (ubuntu for google/sil/manual, macOS
     for macos)

### Phase D — Test fixtures + acceptance

8. Add a fixture-driven test: small formula YAML + small TTF → run
   bin/build locally → assert audit YAML has:
   - Populated `blocks:` array (not empty)
   - Populated `unicode_scripts:` array (not empty)
   - `ucode_version:` field (not `fontisan_version:` for audit producer)
   - `coverage:` section when universal-set reference is passed

## Acceptance

- [ ] `bin/build` invokes `ucode audit font` (not Fontisan)
- [ ] UCD stub hack removed
- [ ] Audit YAMLs include populated `blocks:` and `unicode_scripts:`
- [ ] Audit YAML carries `ucode_version` field (replaces `fontisan_version`)
- [ ] WOFF conversion still works (`Fontisan::ConvertCommand`)
- [ ] Gemfile lists `ucode` and `fontisan` (0.3.0+) as runtime deps
- [ ] At least one formula end-to-end produces a complete audit YAML
- [ ] GHA workflow runs to completion on a small formula subset

## Dependencies / blockers

- **TODO 05** — ucode 0.1.1 published (bin/build will `gem install ucode`)
- **TODO 06** + **TODO 07** — fontisan 0.3.0 published (bin/build can't
  require both old and new fontisan)
- **TODO.new 35** + **TODO.new 41** — universal-set production + archive
  bridge (Phase B depends on these)

## References

- `fontist-archive-private/bin/build` — current implementation
- [TODO 06](06-fontisan-remove-audit.md) — fontisan audit removal
- [TODO 07](07-fontisan-remove-ucd.md) — fontisan UCD removal
- [TODO.new 40](../TODO.new/40-archive-private-uses-ucode-audit.md) — earlier sketch
- `fontist.org/coverage-architecture.md` — updated architecture doc
