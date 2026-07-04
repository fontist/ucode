# TODO 12 — Add `CodepointMapper` strategy success-path specs

## Status

Pending. Audit finding S2. **Depends on TODOs 08 and 09.**

## Why

`spec/ucode/glyphs/embedded_fonts/catalog_spec.rb:64-96` covers
`CodepointMapper` with two cases — both "returns `{}` when X". The
success path for each of the three strategies (ToUnicode,
ContentStreamCorrelator, TraceCorrelator) is unspecced at the unit
level. Only the integration spec exercises the happy paths, and it
requires mutool.

After TODO 09 each strategy is independently testable. After TODO 08
the `Mutool` collaborator is injectable. Both unblock this work.

## Files

- `spec/ucode/glyphs/embedded_fonts/codepoint_mapper_spec.rb` (NEW)
  — splits the existing `describe CodepointMapper` block out of
  `catalog_spec.rb`.
- `spec/ucode/glyphs/embedded_fonts/codepoint_mapper/`
  - `tounicode_strategy_spec.rb`
  - `correlator_strategy_spec.rb`
  - `trace_strategy_spec.rb`
- Remove the orphaned `describe CodepointMapper` block from
  `catalog_spec.rb` (it tests the wrong file).

## Design

### Strategy specs

```ruby
describe CodepointMapper::ToUnicodeStrategy do
  let(:mutool) { StubMutool.new(responses: { "show:-b:..." => CMAP_TEXT }) }
  let(:strategy) { described_class.new(mutool: mutool) }

  describe "#supports?" do
    it "is true when descriptor has tounicode_ref and Identity CIDMap" do
      expect(strategy.supports?(descriptor(tounicode_ref: 7))).to be(true)
    end

    it "is false when tounicode_ref is nil" do
      expect(strategy.supports?(descriptor(tounicode_ref: nil))).to be(false)
    end
  end

  describe "#map" do
    it "parses the CMap stream and returns {codepoint => gid}" do
      result = strategy.map(descriptor(tounicode_ref: 7))
      expect(result[0x10D40]).to eq(174)
      expect(result[0x10D41]).to eq(175)
    end

    it "returns {} when the CMap stream is empty" do
      mutool.responses["show:-b:..."] = ""
      expect(strategy.map(descriptor(tounicode_ref: 7))).to eq({})
    end
  end
end
```

Similar for `CorrelatorStrategy` (uses `Mutool::Draw#svg` + a real
`ContentStreamCorrelator` with a known SVG fixture) and
`TraceStrategy` (uses `PageTraceCache` from TODO 10 + a real
`TraceCorrelator` with synthetic `TraceGlyph` arrays).

### Orchestrator spec

```ruby
describe CodepointMapper do
  let(:tounicode)   { strategy_double(supports: true,  map: { 0x41 => 1 }) }
  let(:correlator)  { strategy_double(supports: false, map: {}) }
  let(:trace)       { strategy_double(supports: false, map: {}) }
  let(:mapper) { described_class.new(strategies: [tounicode, correlator, trace]) }

  it "returns the first non-empty strategy result" do
    descriptor = RawFontDescriptor.new(cid_map_kind: :identity, ...)
    expect(mapper.map(descriptor)).to eq({ 0x41 => 1 })
  end

  it "returns {} when no strategy supports the descriptor" do
    mapper = described_class.new(strategies: [
      strategy_double(supports: false, map: {}),
    ])
    expect(mapper.map(descriptor)).to eq({})
  end

  it "returns {} when cid_map_kind is not :identity" do
    descriptor = RawFontDescriptor.new(cid_map_kind: nil, ...)
    expect(mapper.map(descriptor)).to eq({})
  end
end
```

Note: `strategy_double` here is NOT an RSpec `double()` — the global
rule forbids doubles. It's a file-scope stub class:

```ruby
class StubStrategy < CodepointMapper::Strategy
  def initialize(supports:, map:)
    @supports = supports
    @map = map
  end
  def supports?(_d) = @supports
  def map(_d) = @map
end
```

## Acceptance

- All three strategy classes have unit specs covering both `supports?`
  branches and at least two `#map` cases (success + empty result).
- `CodepointMapper` orchestrator specs verify the chain semantics
  (first-non-empty wins).
- `catalog_spec.rb` no longer contains a `describe CodepointMapper`
  block — it lives in its own file.
- `bundle exec rspec spec/ucode/glyphs/embedded_fonts/codepoint_mapper_spec.rb`
  passes without mutool.
- `grep -r "double(" spec/` returns nothing (no doubles introduced).
