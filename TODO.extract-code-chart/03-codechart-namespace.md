# TODO 03 — CodeChart namespace

## Status

Pending. Depends on TODO 02 (block name resolver) so the Extractor
can consume it; depends on TODO 01 (error class) so the namespace
can declare typed errors.

## Goal

Establish the `Ucode::CodeChart` namespace as the home for the
Code Charts per-codepoint extraction feature. The REQ calls this
namespace `Ucode::CodeChart::*`; we follow the REQ.

This is the autoload-hub file plus the autoload declaration in
`lib/ucode.rb`.

## Files

- `lib/ucode/code_chart.rb` — new autoload hub (defines
  `Ucode::CodeChart` and declares child autoloads).
- `lib/ucode.rb` — add `autoload :CodeChart, "ucode/code_chart"` in
  the namespace-hubs block.

## Design

### Autoload hub shape

```ruby
# lib/ucode/code_chart.rb
module Ucode
  module CodeChart
    autoload :Extractor, "ucode/code_chart/extractor"
    autoload :Provenance, "ucode/code_chart/provenance"
    autoload :Sidecar, "ucode/code_chart/sidecar"
    autoload :Writer, "ucode/code_chart/writer"
  end
end
```

Per the global rule (`~/.claude/CLAUDE.md`): declare autoloads in the
immediate parent namespace's file. `Ucode::CodeChart` is the immediate
parent of `Extractor`, `Provenance`, `Sidecar`, `Writer`; this file
is the immediate parent's file.

`Ucode` is the immediate parent of `CodeChart`; the autoload
declaration `autoload :CodeChart, "ucode/code_chart"` goes in
`lib/ucode.rb`.

### Why a new namespace (not under `Ucode::Glyphs`)

`Ucode::Glyphs::*` is the existing 4-tier sourcing pipeline
(`EmbeddedFonts`, `RealFonts`, `LastResort`, `Writer`). The REQ's
`CodeChart::*` is a feature-facing namespace that orchestrates the
glyphs pipeline for one specific use case (extracting from a per-block
PDF for the essenfont donor pipeline). Keeping the feature-facing
namespace separate from the implementation namespace:

- Lets callers say `Ucode::CodeChart.extract(block: "Sidetic")`
  without first knowing about `Glyphs::EmbeddedFonts`.
- Makes it easy to swap the implementation later (different
  resolution strategy, alternative PDF parser) without breaking the
  public API.
- Keeps `Glyphs::` focused on tier mechanics, free of feature
  ergonomics.

The REQ's namespace name is what we use.

## Acceptance

- `lib/ucode/code_chart.rb` exists with the autoload declarations.
- `lib/ucode.rb` has the new `autoload :CodeChart, "ucode/code_chart"`
  in the namespace-hubs block.
- `Ucode::CodeChart` resolves to a module without loading any of its
  children.

## Out of scope

- `Ucode::CodeChart::Command` (Thin wrapper). The CLI lives in
  `lib/ucode/cli.rb` per the existing pattern; no separate
  `Commands::CodeChartCommand` is introduced (single source of
  truth for CLI dispatch).