# 05. Version resolver

**Goal**: Resolve `"latest"` / `"17"` / `"17.0"` / `"17.0.0"` to a canonical version
string. Validate against known versions. Ported from fontisan.

**Depends on**: 03, 04.

**Files**:
- `lib/ucode/version_resolver.rb`
- `spec/ucode/version_resolver_spec.rb`

## Tasks

- [ ] Port `Fontisan::Ucd::VersionResolver` → `Ucode::VersionResolver`.
- [ ] `resolve(intent)` returns canonical version string; raises
      `Ucode::UnknownVersionError` with the original intent in the message.
- [ ] `validate!(version)` — raises if not in known list.
- [ ] `Config.known_versions` is the source of truth (no hardcoded list in the resolver).

## Acceptance criteria

- `resolve("latest")` returns `Config.default_version`.
- `resolve("17.0.0")` returns `"17.0.0"` when in known list.
- `resolve("99")` raises `Ucode::UnknownVersionError` whose message includes `"99"`.
- No mutation of input.

## Architectural notes

- Version canonicalization is a precondition for every fetch/build/cache lookup. Centralize
  it here so callers never roll their own.
