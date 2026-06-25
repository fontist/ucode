# 13. CodePoint — emoji, identifier, normalization, binary properties

**Goal**: The remaining property bundles. Emoji and Identifier are structured;
Normalization has typed QC fields; BinaryProperties is an open set of long names.

**Depends on**: 09.

**Files**:
- `lib/ucode/models/codepoint/emoji.rb`
- `lib/ucode/models/codepoint/identifier.rb`
- `lib/ucode/models/codepoint/normalization.rb`
- `lib/ucode/models/codepoint/binary_properties.rb`
- Specs.

## Tasks

- [ ] `Emoji`:
  - `attribute :is_emoji, :boolean` (Emoji)
  - `attribute :is_presentation_default, :boolean` (EPres)
  - `attribute :is_modifier, :boolean` (EMod)
  - `attribute :is_base, :boolean` (EBase)
  - `attribute :is_component, :boolean` (EComp)
  - `attribute :is_extended_pictographic, :boolean` (ExtPict)
- [ ] `Identifier`:
  - `attribute :is_start, :boolean` (IDS)
  - `attribute :is_continue, :boolean` (IDC)
  - `attribute :xid_start, :boolean`
  - `attribute :xid_continue, :boolean`
  - `attribute :status, :string` — from IdentifierStatus.txt (allowed/restricted)
  - `attribute :types, :string, collection: true` — from IdentifierType.txt
- [ ] `Normalization`:
  - `attribute :nfc_qc, :string` (Y/N/M)
  - `attribute :nfd_qc, :boolean` (derived from NFD_QC = Y/N)
  - `attribute :nfkc_qc, :string` (Y/N/M)
  - `attribute :nfkd_qc, :boolean`
  - `attribute :composition_exclusion, :boolean` (Comp_Ex)
  - `attribute :is_cased, :boolean`
  - `attribute :changes_when_casefolded, :boolean`
  - `attribute :changes_when_casemapped, :boolean`
  - `attribute :changes_when_nfkc_casefolded, :boolean`
- [ ] `BinaryProperties`: NOT a class with 30 boolean attrs. Instead, CodePoint holds
      `attribute :binary_properties, :string, collection: true` — an array of enabled
      property long names (`"Alphabetic"`, `"Uppercase"`, `"White_Space"`, `"Math"`, …).
      The set comes from `PropertyAliases.txt` + `DerivedCoreProperties.txt`.
- [ ] Autoloads.

## Acceptance criteria

- Round-trip on each.
- Sample U+0041 has `binary_properties` including `"Alphabetic"`, `"Uppercase"`,
  `"ID_Start"`, `"XID_Start"`, `"Grapheme_Base"`.
- Sample U+1F600 (😀) has `emoji.is_emoji == true`, `emoji.is_extended_pictographic == true`.
- Sample U+00DF has `normalization.nfkc_qc == "N"` (changes under NFKC).

## Architectural notes

- **BinaryProperties as a set, not 30 booleans**: open/closed principle. Unicode adds new
  binary properties across versions; a set absorbs the addition without model changes.
- The site renders the set as a tag cloud.
