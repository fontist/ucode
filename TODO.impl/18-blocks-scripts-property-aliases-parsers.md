# 18. Blocks + Scripts + ScriptExtensions + PropertyAliases parsers

**Goal**: The range-property parsers plus the alias lookup parsers. Same pattern as the
base: streaming, yielding typed records.

**Depends on**: 17.

**Files**:
- `lib/ucode/parsers/blocks.rb`
- `lib/ucode/parsers/scripts.rb`
- `lib/ucode/parsers/script_extensions.rb`
- `lib/ucode/parsers/property_aliases.rb`
- `lib/ucode/parsers/property_value_aliases.rb`
- Specs + sliced fixtures for each.

## Tasks

- [ ] `Blocks` parser yields `Block` instances (range + name). Order is by `first_cp`.
- [ ] `Scripts` parser yields `Script` entries (range + ISO 15924 code).
- [ ] `ScriptExtensions` parser yields `ScriptExtension` tuples `(cp, script_code)` —
      a single codepoint may have many. Coordinator merges into `CodePoint.script_extensions`.
- [ ] `PropertyAliases` parser yields `PropertyAlias` records.
- [ ] `PropertyValueAliases` parser yields `PropertyValueAlias` records.
- [ ] All five parsers live in the parsers hub and are autoloaded from
      `lib/ucode/parsers.rb`.

## Acceptance criteria

- Sample fixture: 3 entries → 3 Block instances.
- Round-trip on each emitted model.
- `PropertyValueAliases` correctly parses multi-line entries where a single short code
  maps to multiple long names (one per line, indented continuation).

## Architectural notes

- These parsers are independent of UnicodeData and don't share state with it. Each is a
  pure function of one file.
- **Why enumerators**: `Ucode::Parsers::Blocks.each_record(path)` returns an
  `Enumerator::Lazy` when no block given. Lets Coordinator compose
  `UnicodeData.each.zip(Blocks.each).map { |cp, blocks| ... }` without intermediate
  Arrays.