# TODO 09 — Refactor `CodepointMapper` to a Strategy chain

## Status

Pending. Audit findings A3 + A4 (OCP violation). **Depends on
TODO 08.**

## Why

`lib/ucode/glyphs/embedded_fonts/codepoint_mapper.rb:40-50` hard-codes
the strategy chain:

```ruby
def map(descriptor)
  return {} unless descriptor.cid_map_kind == :identity

  from_tounicode = map_from_tounicode(descriptor.tounicode_ref)
  return from_tounicode unless from_tounicode.empty?

  from_correlator = map_from_correlator(descriptor.font_obj_id)
  return from_correlator unless from_correlator.empty?

  map_from_trace(descriptor.base_font)
end
```

Adding a 4th strategy requires editing this method — OCP violation.
The 3 paths also embed 3 different subprocess shapes (TODO 08) and
3 different collaborators (ToUnicode CMap parser, ContentStreamCorrelator,
TraceCorrelator). One class, 3 concerns.

## Files

```
lib/ucode/glyphs/embedded_fonts/
  codepoint_mapper.rb             # becomes pure orchestrator
  codepoint_mapper/
    strategy.rb                   # abstract base
    tounicode_strategy.rb         # was map_from_tounicode
    correlator_strategy.rb        # was map_from_correlator
    trace_strategy.rb             # was map_from_trace
```

## Design

### Abstract strategy

```ruby
class CodepointMapper::Strategy
  # @param descriptor [RawFontDescriptor]
  def supports?(descriptor)
    raise NotImplementedError
  end

  # @param descriptor [RawFontDescriptor]
  # @return [Hash{Integer=>Integer}] codepoint => gid; empty when
  #   the strategy cannot produce a mapping
  def map(descriptor)
    raise NotImplementedError
  end
end
```

### Three subclasses

Each strategy owns ONE subprocess call (via the injected `Mutool`
from TODO 08) and ONE collaborator:

- `ToUnicodeStrategy` — uses `Mutool::Show#stream`, delegates parsing
  to `ToUnicode`.
- `CorrelatorStrategy` — uses `Mutool::Draw#svg`, delegates matching
  to `ContentStreamCorrelator`. Reads its Config from
  `correlator_configs[descriptor.font_obj_id]`.
- `TraceStrategy` — uses `Mutool::Trace`, delegates matching to
  `TraceCorrelator`. Consumes the per-page trace cache from TODO 10
  when available.

`supports?` for each:

- ToUnicode: `descriptor.tounicode_ref && descriptor.cid_map_kind == :identity`
- Correlator: `correlator_configs.key?(descriptor.font_obj_id)`
- Trace: always true (fallback) — but consumes the page trace cache,
  which may be empty if no font lacks `/ToUnicode`.

### Pure orchestrator

```ruby
class CodepointMapper
  def initialize(strategies:)
    @strategies = strategies
  end

  def map(descriptor)
    return {} unless descriptor.cid_map_kind == :identity

    @strategies.each do |s|
      next unless s.supports?(descriptor)

      result = s.map(descriptor)
      return result unless result.empty?
    end
    {}
  end
end
```

A factory (or the Catalog) builds the strategy chain in priority
order. Adding a 4th strategy = one new subclass + one entry in the
chain — no edit to `CodepointMapper#map`.

## Acceptance

- `CodepointMapper#map` contains zero subprocess calls.
- `CodepointMapper` is one screen of pure orchestration.
- Each strategy class is independently testable with stub `Mutool`
  + stub collaborators.
- Catalog still produces the same FontEntry shape with the same
  codepoint_to_gid maps for a real Code Charts PDF.
- All existing specs pass (skipped on no-mutool as today).
