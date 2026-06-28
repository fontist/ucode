# 40 — fontist-archive-private bin/build uses ucode audit

## Goal

Refactor `fontist-archive-private/bin/build` so it invokes
`ucode audit font` instead of the dead `Fontisan::Commands::AuditCommand`
path. The current script (last touched when fontisan still owned audits)
has a UCD-stub hack at lines 13–21 that returns empty UCD data —
exactly the functionality ucode provides natively via its own UCD
parse + cache.

This TODO is the engineering work to make the architecture doc
(coverage-architecture.md §"Build Pipeline") match reality.

## Why a separate TODO

The audit migration (TODOs 06–12) ported fontisan's audit subsystem
into ucode. The CLI command `ucode audit font <path>` produces the
same shape of YAML that `Fontisan::Commands::AuditCommand` used to.
But fontist-archive-private's `bin/build` was never updated to call
the new tool — it still requires `fontisan` and stubs UCD out.

Three problems with the current state:

1. **Coverage aggregations are empty.** Every audit YAML currently
   has `blocks: []`, `unicode_scripts: []` because the UCD stub
   returns nil. Consumers (fontist.org's coverage browser) see
   per-font cmap lists but no per-block fill ratios.

2. **Two sources of truth for "what's in UCD."** fontisan used to
   auto-download `ucd.all.flat.xml` (removed per CLAUDE.md); the
   stub hack papers over the missing file. ucode has its own
   authoritative UCD parse under `~/.cache/ucode/`.

3. **No universal-set reference.** Even if the UCD stub were removed,
   fontisan can't compare a font's cmap to the canonical universal
   glyph set. ucode can (TODO 35 produces the set; TODO 36 adds the
   comparison).

## Scope

### Phase A — Swap audit invocation

1. Replace lines 100–115 of `bin/build`:

   ```ruby
   # OLD (broken — uses Fontisan::Commands::AuditCommand + UCD stub)
   cmd = Fontisan::Commands::AuditCommand.new(face_path, font_index: font_index, no_codepoints: false)
   report = cmd.run
   File.write(audit_path, report.to_yaml)
   ```

   with:

   ```ruby
   # NEW — invoke ucode audit via CLI (shelling out keeps the build
   # script decoupled from ucode's internal API)
   system("ucode", "audit", "font", face_path,
          "--font-index", font_index.to_s,
          "--output", audit_path,
          out: File::NULL, err: verbose ? $stderr : File::NULL)
   ```

   OR via the Ruby API if shell-out overhead becomes measurable:

   ```ruby
   Ucode::Commands::Audit::FontCommand.new.call(
     path: face_path,
     font_index: font_index,
     output: audit_path,
   )
   ```

2. **Remove the UCD stub hack** (lines 13–21 of `bin/build`). ucode
   has its own UCD cache; no stub needed.

3. **Update Gemfile** — add `ucode` gem, keep `fontisan` for
   ConvertCommand (WOFF generation), keep `excavate` for archive
   extraction.

### Phase B — Universal-set reference (after TODO 35)

4. When the universal set is published (TODO 35 + TODO 41 bridge),
   pass `--reference-universal-set=<path>` to every `ucode audit font`
   invocation. The audit YAML gains a `coverage` section comparing
   the font's cmap to the canonical per-block codepoint lists.

5. The universal set lives in fontist-archive-public under
   `unicode/universal-glyph-set/` (per TODO 41). fontist-archive-private's
   CI checks it out shallow before invoking bin/build, so the audit
   can reference it.

### Phase C — Cleanup

6. Remove the `module Fontisan::Audit::Context` monkey-patch
   entirely. Dead code once fontisan's AuditCommand is no longer
   called.

7. Update `coverage-architecture.md` examples to match the new
   `ucode_version` field in the audit YAML schema (replaces
   `fontisan_version` for the audit producer; fontisan_version may
   still appear as the parser-layer version).

8. Specs: add a test fixture — small formula YAML + small TTF →
   assert bin/build produces an audit YAML with non-empty `blocks`
   and the new `ucode_version` field.

## Acceptance

- [ ] `bin/build` invokes `ucode audit font` (not Fontisan)
- [ ] UCD stub hack removed
- [ ] Audit YAMLs include populated `blocks:` and `unicode_scripts:`
      (not empty arrays)
- [ ] Audit YAML carries `ucode_version` field
- [ ] Universal-set comparison lands when TODO 35 + TODO 41 are done
- [ ] At least one formula end-to-end (e.g. `google/abeezee`) produces
      a complete audit YAML via the new path

## References

- `fontist-archive-private/bin/build` — current implementation
- `fontist.org/coverage-architecture.md` — target architecture (updated)
- [TODO 36](36-per-font-coverage-audit.md) — consumes the new audit data
- [TODO 41](41-ucode-unicode-archive-bridge.md) — universal-set publishing
