# 28. Aggregator — coverage analysis

**Goal**: Port fontisan's `Aggregator` verbatim. Pure module: given codepoints and
indices, return aggregated summaries. No I/O.

**Depends on**: 26.

**Files**:
- `lib/ucode/aggregator.rb`
- `spec/ucode/aggregator_spec.rb`.

## Tasks

- [ ] Port `Fontisan::Ucd::Aggregator` → `Ucode::Aggregator`. API preserved:
  - `aggregate_blocks(codepoints, blocks_index)` → array of `{ name:, first_cp:,
    last_cp:, total:, covered:, fill_ratio:, complete: }`
  - `aggregate_scripts(codepoints, scripts_index)` → sorted unique script names
- [ ] Use `Ucode::Index` (not `Fontisan::Ucd::Index`).

## Acceptance criteria

- Sample input `[0, 65, 200]` with the Basic Latin + Latin-1 Supplement indices returns
  two block summaries, the first with `covered: 2`, the second with `covered: 1`.
- `aggregate_scripts([65, 66], scripts_index)` returns `["Latin"]`.

## Architectural notes

- This is the entry point for fontisan's audit feature. Once ucode exposes this, fontisan
  can drop its version entirely.