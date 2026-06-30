# TODO 07 — CodeChart CLI

## Status

Pending. Depends on TODO 06 (Writer), TODO 04 (Extractor),
TODO 02 (block name resolver).

## Goal

`ucode code-chart fetch | extract | list` — the REQ (R4) commands.
Thin Thor wrappers that delegate to the existing `CodeChart::*`
modules. No orchestration logic in the CLI; every command is a
single delegation.

## Files

- `lib/ucode/cli.rb` — add the `CodeChartCmd` Thor subcommand class.
- `spec/ucode/cli_spec.rb` (extend existing) — verify the new
  subcommand wires up.

## Design

### Subcommand shape

```ruby
class Cli < Thor
  # …existing commands…

  class CodeChartCmd < Thor
    desc "fetch --block BLOCK", "Download the Code Charts PDF for a block"
    option :block, type: :string, required: true,
                  desc: "Block identifier (e.g. Sidetic)"
    def fetch
      puts JSON.pretty_generate(
        Commands::FetchCommand.new.fetch_charts(
          VersionResolver.resolve(nil),
          block_first_cps: [block_first_cp!(options[:block])],
        ),
      )
    end

    desc "extract --block BLOCK --to DIR", "Extract per-codepoint SVG + provenance sidecars"
    option :block, type: :string, required: true,
                  desc: "Block identifier (e.g. Sidetic)"
    option :to, type: :string, required: true,
                desc: "Output directory"
    def extract
      # ...
    end

    desc "list", "List blocks that have Code Charts PDFs available locally"
    def list
      # ...
    end
  end

  desc "code-chart", "Extract per-codepoint SVG glyphs from Unicode Code Charts PDFs"
  subcommand "code-chart", CodeChartCmd
end
```

### `extract` flow

```ruby
def extract
  Ucode::Commands::FetchCommand.new.fetch_charts(
    VersionResolver.resolve(nil),
    block_first_cps: [block_first_cp!(options[:block])],
  )
  blocks_txt = Ucode::Cache.ucd_dir(VersionResolver.resolve(nil)).join("Blocks.txt")
  block = Parsers::Blocks.find_by_name(blocks_txt, options[:block]) or
    raise Thor::Error, "Unknown block: #{options[:block].inspect}"
  pdf = Ucode::Glyphs::PdfFetcher.new(
    VersionResolver.resolve(nil),
    monolith_path: nil,
    blocks: [block],
  ).fetch(block_first_cp: block.range_first, force: false) or
    raise Thor::Error, "PDF unavailable for block #{options[:block]}"

  writer = Ucode::CodeChart::Writer.new(
    output_root: Pathname.new(options[:to]),
    pdf_path: pdf,
    blocks_txt: blocks_txt,
  )
  summary = writer.write(block)
  puts JSON.pretty_generate(summary.to_h.compact)
end

def block_first_cp!(block_id)
  cache = Ucode::Cache.ucd_dir(VersionResolver.resolve(nil))
  block = Ucode::Parsers::Blocks.find_by_name(cache.join("Blocks.txt"), block_id)
  raise Thor::Error, "Unknown block: #{block_id.inspect}" unless block
  block.range_first
end
```

### Why `Ucode::Commands::FetchCommand.new.fetch_charts` for fetch

`fetch_charts` is the existing CLI hook for "download a Code Charts
PDF for these block first-cps." We just call it with the block's
first cp. Reuse, don't reimplement.

### Why resolve version once at the top of `extract`

Per Candidate 4 of the architecture review (`refactor/build-context-resolve-version-once`,
merged): every CLI method resolves the version once and threads it
through. This CLI method does the same — one call per invocation.

### Why no separate `Commands::CodeChartCommand` class

Following the existing pattern (e.g. `Cli::Audit` calls
`Commands::Audit::*Command` *only* when the logic is non-trivial).
The CodeChart commands are trivial delegations — a one-liner each.
The CLI methods call `CodeChart::Writer` and `CodeChart::Extractor`
directly. Adding a `Commands::CodeChartCommand` class would be
indirection without a payoff.

If the extract logic grows (e.g. progress reporting, partial
extraction), extract it into a Command class at that point.

## Acceptance

- `ucode code-chart fetch --block Sidetic` downloads the PDF.
- `ucode code-chart extract --block Sidetic --to /tmp/s/` extracts
  to the given directory.
- `ucode code-chart list` prints available blocks.
- Unknown block names produce a clean error, not a stack trace.
- The CLI matches the REQ's signature exactly.

## Out of scope

- `--version` flag (the REQ doesn't specify, and existing commands
  default to the configured version).
- `--format svg|glif` (the REQ specifies SVG; `.glif` output is a
  future extension).