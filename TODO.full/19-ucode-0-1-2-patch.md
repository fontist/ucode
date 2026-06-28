# 19 — ucode 0.1.2 patch: include FontWriter + universal-set fixes

## Goal

After TODO.full/13 (FontWriter) lands in fontisan, bump ucode to 0.1.2
with whatever fixes accumulated. Keep the gem install path stable for
fontist-archive-private CI.

## Why a separate TODO

ucode 0.1.1 (TODO.full/05) ships the audit subsystem + BlockFeedEmitter.
0.1.2 is a routine patch — no SemVer drama, just iteration. Bundles
whatever real-data fixes surface when CI actually runs against all
formulas.

## Scope

- Bump `lib/ucode/version.rb` to `0.1.2`
- Add CHANGELOG entry (typically: 1-2 fixes)
- Run full test suite + rubocop
- Open PR + tag + release per standard release process

## Acceptance

- [ ] Version bumped
- [ ] CHANGELOG documents 0.1.2
- [ ] Specs green
- [ ] Tag v0.1.2 + `rake release` (with explicit user authorization)

## References

- [TODO.full/05](05-ucode-0-1-1-release.md) — prior release process
