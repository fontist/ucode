# 01. Gem skeleton + autoload hub + Thor CLI

**Goal**: Stand up the runnable gem: `bundle exec rspec` and `bundle exec ucode` both work
(empty), `bundle exec rubocop` is clean, every namespace has a hub file with autoloads.

**Depends on**: nothing (this is the foundation).

**Files**:
- `ucode.gemspec` — gem metadata + deps (`lutaml-model ~> 0.8`, `nokogiri ~> 1.16`,
  `thor ~> 1.3`, `sqlite3 ~> 2.0`, `pathname`, `logger`, `base64`; dev: `rspec`, `rubocop`,
  `rake`, `simplecov`).
- `lib/ucode.rb` — top-level hub. Defines `module Ucode`; autoloads sub-hubs (`Config`,
  `Error`, `Cache`, `VersionResolver`, `Fetch`, `Models`, `Parsers`, `Coordinator`,
  `Index`, `Database`, `Aggregator`, `Repo`, `Glyphs`, `Site`, `Cli`).
- `lib/ucode/version.rb` — `VERSION = "0.1.0"`.
- `lib/ucode/config.rb` — see TODO 03.
- `lib/ucode/error.rb` — see TODO 03.
- `lib/ucode/cli.rb` — Thor class with no commands yet (subcommands added by later TODOs).
- `exe/ucode` — executable shebang that calls `Ucode::Cli.start(ARGV)`.
- `Gemfile`, `Gemfile.lock` (after `bundle install`).
- `Rakefile` — `task default: [:spec, :rubocop]`.
- `.rspec` — `--format documentation --color`.
- `.rubocop.yml` — inherit fontisan's rules; enable `Style/Documentation`, ban
  `Send`, `InstanceVariableSet`, `InstanceVariableGet`, `RespondTo`, `RequireRelative`.
- `.gitignore` — `/data/`, `/output/`, `/site/`, `/.bundle/`, `/pkg/`, `/coverage/`,
  `/tmp/`. **Never** ignore `ucd.all.flat.xml`, `ucd.all.flat.zip`, `CodeCharts.pdf`.
- `spec/spec_helper.rb` — simplecov start, `$LOAD_PATH.unshift("lib")`, no doubles helper.
- `spec/ucode_spec.rb` — smoke spec asserting `Ucode::VERSION` is a string.

## Tasks

- [ ] Create gemspec; pin Ruby `>= 3.1`.
- [ ] Write `lib/ucode.rb` with autoloads for every sub-hub (sub-hub files may be empty
      stubs for now; they're filled by later TODOs).
- [ ] Stub each sub-hub file (`lib/ucode/fetch.rb`, `lib/ucode/models.rb`, etc.) with the
      `module Ucode::X` declaration and a TODO comment pointing to the right impl TODO.
- [ ] Write `lib/ucode/cli.rb` — Thor class with `desc "version"` only.
- [ ] `bundle install`, verify `bundle exec rspec` runs (one passing smoke spec).
- [ ] Verify `bundle exec rubocop` is clean.
- [ ] Verify `bundle exec ucode version` prints `ucode 0.1.0`.

## Acceptance criteria

- `bundle exec rspec` passes with one example.
- `bundle exec ucode version` works.
- `find lib -name '*.rb' | xargs grep -l "require_relative"` returns nothing.
- `find lib spec -name '*.rb' | xargs grep -lw "send"` returns nothing (no `send` to
  private methods).
- `.gitignore` does NOT mention the three source files.

## Architectural notes

- **Autoload discipline is the load-path strategy.** Every `module`/`class` we add gets
  one `autoload` line in its immediate parent namespace's hub file. This is the only
  correct way to avoid `require_relative` in a Ruby library.
- The sub-hub stubs (empty `module Ucode::Models; end`) are deliberate — they make
  autoloads resolvable from day one.
