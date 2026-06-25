# 03. Errors + Config

**Goal**: Single typed-error hierarchy and single configuration object. No `ENV` reads
outside `Config`; no string-only raises anywhere.

**Depends on**: 01.

**Files**:
- `lib/ucode/error.rb` — namespace hub with autoloads for subclasses.
- `lib/ucode/errors/{fetch,network,checksum,parse,malformed_line,unknown_property,lookup,database_missing,unknown_version,glyph,pdf_render,grid_detection}.rb`
- `lib/ucode/config.rb` — fields with defaults; reads `ENV` here only.
- `spec/ucode/error_spec.rb` — every subclass is an `Ucode::Error`, message carries context.
- `spec/ucode/config_spec.rb` — defaults, env override, immutability of returned object.

## Tasks

- [ ] Define `Ucode::Error < StandardError` with a constructor accepting `message:` plus
      optional `context:` hash merged into the message.
- [ ] One file per leaf error class, all `< Ucode::Error` (or the appropriate mid-level
      parent).
- [ ] Define `Ucode::Config` with `attr_reader` for every field and a private `attr_writer`
      or a `Configure` DSL (`Ucode.configure { |c| c.parallel_workers = 4 }`).
- [ ] All env var reads live in `Config`'s default initializers; nowhere else.
- [ ] Add a global `Ucode.configuration` accessor returning a memoized instance, with
      `Ucode.configure` for tests to override per-example.

## Acceptance criteria

- Every error raised anywhere in the codebase is `is_a?(Ucode::Error)`.
- `Config.new.parallel_workers` is an Integer.
- `Ucode.configure { |c| c.cache_root = "/tmp/x" }` then `Ucode.configuration.cache_root`
  returns `/tmp/x`.
- No `ENV[` outside `lib/ucode/config.rb` (`grep -rn 'ENV\[' lib/` returns one match).

## Architectural notes

- **SSOT for env vars**: `Config` is the only consumer of `ENV`. Tests inject a `Config`
  instance; production reads `ENV` once at boot.
- **Error context**: errors carry structured context (`codepoint:`, `file:`, `line:`) so
  CLI formatters can render useful diagnostics without re-parsing strings.
