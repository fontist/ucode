# 35. CLI commands (Thor)

**Goal**: Wire every subsystem into `bin/ucode` Thor commands.

**Depends on**: all prior TODOs.

**Files**:
- `lib/ucode/cli.rb` — top-level Thor class with subcommand dispatch.
- `lib/ucode/commands/fetch.rb`
- `lib/ucode/commands/parse.rb`
- `lib/ucode/commands/glyphs.rb`
- `lib/ucode/commands/site.rb`
- `lib/ucode/commands/lookup.rb`
- `lib/ucode/commands/cache.rb`
- `lib/ucode/commands/build.rb`
- Specs using a CLI runner (invoke Thor in-process).

## Tasks

- [ ] `ucode fetch ucd [version]` — `Ucode::Fetch::UcdZip.call(version, force: false)`.
- [ ] `ucode fetch unihan [version]`.
- [ ] `ucode fetch charts [version] [--block=...]`.
- [ ] `ucode parse [version] [--to=output/]` — runs Coordinator → Repo writers.
- [ ] `ucode glyphs [version] [--block=...] [--force]` — runs Glyph::Writer.
- [ ] `ucode site init` / `ucode site build`.
- [ ] `ucode lookup block <codepoint>` / `ucode lookup script <codepoint>` /
      `ucode lookup char <codepoint>` — uses `Ucode::Database`.
- [ ] `ucode cache list` / `ucode cache info [version]` / `ucode cache remove <version>`.
- [ ] `ucode build [version] [--to=...]` — full pipeline: fetch + parse + glyphs +
      site. Resumable.
- [ ] Every command delegates to a `Commands::*Command` class returning structured
      output; the Thor method handles formatting (same pattern as fontisan).
- [ ] `ucode version` prints `ucode <VERSION>`.

## Acceptance criteria

- `ucode --help` lists all subcommands.
- `ucode fetch ucd 17.0.0` (with network) populates the cache.
- `ucode build 17.0.0` runs end-to-end without errors on a sliced fixture.
- Every command has at least one spec.

## Architectural notes

- **Thin Thor**: command classes do the work; Thor is just dispatch + formatting. Same
  pattern as fontisan (proven).
- **Resumable build**: each step is idempotent; `ucode build` can be interrupted and
  re-run safely.