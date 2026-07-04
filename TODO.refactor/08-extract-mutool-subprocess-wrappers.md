# TODO 08 — Extract `Mutool` subprocess wrappers

## Status

Pending. Audit finding A4 (mixed subprocess concerns). **Foundation
TODO — unblocks 09, 10, 11, 12.**

## Why

`CodepointMapper` currently embeds **three** different mutool
subprocess shapes directly in its method bodies:

- `:70` `fetch_tounicode` — `mutool show -o <tmpfile> -b <pdf> <obj>`
- `:96` `render_pages` — `mutool draw -F svg <pdf> <pages...>`
- `:113` `map_from_trace` (via `TraceRunner`) — `mutool trace <pdf> <page>`

`PdfIndexer` has its own:

- `:159` `fetch_objects` — `mutool show -g <pdf> <obj_ids...>`
- `:215` `run_mutool_info` — `mutool info <pdf>`

Each call site does its own `Open3.capture3`, its own error handling
(raise `EmbeddedFontsMissingError` on non-zero exit), and its own
output assembly. There is no seam to inject a fake `mutool` for
specs — the only way to exercise these paths is to have a real
`mutool` binary on PATH (which is why PdfIndexer has zero unit specs
today).

This blocks TODOs 09, 10, 11, 12 — all of which need a testability
seam.

## Files

New namespace `lib/ucode/glyphs/embedded_fonts/mutool.rb`:

```
lib/ucode/glyphs/embedded_fonts/
  mutool.rb                       # autoload hub + Configuration
  mutool/
    info.rb                       # mutool info <pdf>
    show.rb                       # mutool show -g / -b -o <tmp>
    draw.rb                       # mutool draw -F svg <pdf> <pages>
    trace.rb                      # mutool trace <pdf> <page>
```

`TraceRunner` is renamed `Mutool::Trace` (or kept as a thin facade
delegating to it — TBD at implementation time, prefer direct
rename). `TraceGlyph` and `TraceParser` stay where they are
(format-specific value objects, not subprocess wrappers).

## Design

### Single subprocess primitive

```ruby
class Mutool
  # Inject a runner to intercept in tests. Default: real Open3.
  def initialize(runner: Mutool::SystemRunner.new)
    @runner = runner
  end

  class SystemRunner
    def run(*args)
      out, err, status = Open3.capture3(*args)
      raise MutoolError, "mutool failed (#{status.exitstatus}): #{err}" \
        unless status.success?
      out + err
    end
  end
end
```

### One class per subcommand

```ruby
class Mutool::Info < Mutool
  def call(pdf)         # returns raw mutool info text
    @runner.run("mutool", "info", pdf.to_s)
  end
end

class Mutool::Show < Mutool
  def grep(pdf, *obj_ids)        # mutool show -g
    @runner.run("mutool", "show", "-g", pdf.to_s, *obj_ids.map(&:to_s))
  end

  def stream(pdf, obj_id)        # mutool show -b -o <tmpfile>
    Tempfile.create("mutool-stream") do |tmp|
      tmp.close
      @runner.run("mutool", "show", "-o", tmp.path, "-b",
                  pdf.to_s, obj_id.to_s)
      File.binread(tmp.path).force_encoding("UTF-8")
    end
  end
end

class Mutool::Draw < Mutool
  def svg(pdf, *pages)           # mutool draw -F svg
    @runner.run("mutool", "draw", "-F", "svg", pdf.to_s,
                *pages.map(&:to_s))
  end
end

class Mutool::Trace < Mutool
  def call(pdf, *pages)          # mutool trace <pdf> <pages...>
    @runner.run("mutool", "trace", pdf.to_s, *pages.map(&:to_s))
  end
end
```

### Injection in `CodepointMapper` and `PdfIndexer`

Both classes gain a `mutool:` constructor argument defaulting to a
`Mutool::SystemRunner`-backed instance. In production the default is
invisible (zero behavior change). In specs, the test injects a
`Mutool` whose `runner:` returns canned output.

### Error type

Promote `MutoolError < Ucode::GlyphError` as the single failure type
for "mutool itself failed." `EmbeddedFontsMissingError` becomes a
thin rescue-and-rewrap OR is removed in favor of `MutoolError` (pick
one — TBD at impl time; prefer removing `EmbeddedFontsMissingError`
since the only failure mode is "mutool failed", which is what
`MutoolError` says).

## Acceptance

- No `Open3.capture3` call remains in `pdf_indexer.rb`,
  `codepoint_mapper.rb`, or `trace_runner.rb`.
- All public behavior preserved: catalog/codepoint_mapper outputs
  unchanged for real mutool.
- `bundle exec rspec spec/ucode/glyphs/embedded_fonts/` passes.
- A new spec `spec/ucode/glyphs/embedded_fonts/mutool_spec.rb`
  verifies each subcommand class builds the right argv when given a
  stub runner that records calls.

## Out of scope

- CodepointMapper strategy refactor (TODO 09).
- Page trace cache (TODO 10).
- New PdfIndexer / CodepointMapper specs (TODOs 11, 12).

Those land on top of this TODO.
