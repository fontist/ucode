# 19. NameAliases + NamedSequences + SpecialCasing + CaseFolding parsers

**Goal**: The four human-curated / case-handling parsers. Each is independent.

**Depends on**: 17.

**Files**:
- `lib/ucode/parsers/name_aliases.rb`
- `lib/ucode/parsers/named_sequences.rb`
- `lib/ucode/parsers/special_casing.rb`
- `lib/ucode/parsers/case_folding.rb`
- Specs + fixtures.

## Tasks

- [ ] `NameAliases` format:
  - `cp; alias; type` (`type` ∈ `correction`, `control`, `alternate`, `figment`,
    `abbreviation`).
  - Yields `NameAlias` records.
- [ ] `NamedSequences` (a.k.a. `NameSequences.txt`):
  - `cp1 cp2 cp3; NAME` (space-separated codepoints, `;`, then name).
  - Yields `NamedSequence` records (name + ordered list of IDs).
- [ ] `SpecialCasing`:
  - `cp; lc; tc; uc; conditions; # comment`
  - The `lc`/`tc`/`uc` fields are either empty or a space-separated list of codepoints.
  - `conditions` is a space-separated list of context identifiers (`"Final_Sigma"`,
    `"After_I"`, locale codes like `"tr"`, `"az"`).
  - Yields `SpecialCasingRule` records.
  - Coordinator merges into CodePoint.casing.full_*_ids per cp.
- [ ] `CaseFolding`:
  - `cp; status; mapping; # comment`
  - `status` ∈ `C`, `F`, `S`, `T`.
  - `mapping` is one or more space-separated codepoints.
  - Yields `CaseFoldingRule` records.
  - Coordinator merges into CodePoint.case_folding.

## Acceptance criteria

- Round-trip on each emitted model.
- Sample U+00DF yields one SpecialCasing rule with `upper_ids = ["U+0053", "U+0053"]`,
  `conditions = []`.
- Sample U+1E9E (ẞ) yields one rule with `upper_ids = ["U+0053", "U+0053"]`,
  `conditions = ["Final_Sigma"]`.
- CaseFolding U+0041 (A) yields one rule with `status: "C"`, `mapping_ids: ["U+0061"]`.

## Architectural notes

- The condition field of SpecialCasing is the trickiest column. Parsing it as a simple
  space-separated array is the simplest correct shape; filtering by condition is the
  consumer's job.