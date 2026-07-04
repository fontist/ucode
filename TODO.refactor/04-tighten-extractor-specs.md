# TODO 04 — Tighten and rename extractor specs

## Status

Pending. Audit findings S3 + S4.

## Why

Two weak specs in `spec/ucode/code_chart/extractor_spec.rb`:

**S3** (line 88-105) — claims to test "returns Results for codepoints
Pillar 1 (via ToUnicode or trace) can serve" but accepts ANY non-empty
result set:

```ruby
expect(results).not_to be_empty
results.each { |r| expect(r.tier).to eq(:pillar1) }
```

No assertion on which codepoints, count, or tier-mix. The test would
pass if the extractor returned one glyph for U+0000 and nothing else.

**S4** (line 107-114) — title lies:

```ruby
it "yields every codepoint in the block range, even when no tier serves them"
...
expect { extractor.extract }.not_to raise_error
```

The body doesn't verify yielding behavior at all.

## Files

- `spec/ucode/code_chart/extractor_spec.rb`.

## Design

For S3: pin the spec to deterministic outputs by injecting a known
pillar3 source that serves exactly the codepoints the catalog misses
(mirror the pattern in `writer_spec.rb`'s `AlwaysPillar3`). Assert:

- Every Result.tier is `:pillar1` or `:pillar3` (no other tiers
  configured).
- Pillar 1 + Pillar 3 partition the full block range with no gaps
  and no duplicates.

For S4: rename to `"#extract is bounded by the block range and does
not raise when no source serves"` — describes what the spec actually
verifies. Drop the false claim about yielding.

## Acceptance

- Every spec title in `extractor_spec.rb` truthfully describes the
  spec body.
- The "with a Pillar 3 source injected" context asserts the full
  partition, not just "more than zero".
- Specs still skip cleanly when mutool is absent.
