# 08. Plane, Block, Script

**Goal**: The three top-level aggregates that group codepoints.

**Depends on**: 07.

**Files**:
- `lib/ucode/models/plane.rb`
- `lib/ucode/models/block.rb`
- `lib/ucode/models/script.rb`
- Specs for each.

## Tasks

- [ ] `Plane`:
  - `attribute :number, :integer` (0–16)
  - `attribute :name, :string` ("Basic Multilingual Plane", etc.)
  - `attribute :abbrev, :string` ("BMP", "SMP", "SIP", "TIP", "SSP")
  - `attribute :range_first, :integer`, `attribute :range_last, :integer`
  - `attribute :block_ids, :string, collection: true`
- [ ] `Block`:
  - `attribute :id, :string` — original `Blocks.txt` value, verbatim (`ASCII`,
        `CJK_Ext_A`, `Greek_And_Coptic`). **NOT slugified.**
  - `attribute :name, :string` — display name (spaces preserved).
  - `attribute :range_first, :integer`, `attribute :range_last, :integer`
  - `attribute :plane_number, :integer`
  - `attribute :codepoint_ids, :string, collection: true` — only assigned codepoints.
- [ ] `Script`:
  - `attribute :code, :string` — ISO 15924 (`Latn`, `Grek`, `Hani`)
  - `attribute :name, :string`
  - `attribute :codepoint_ids, :string, collection: true`
- [ ] All three pass round-trip shared example.

## Acceptance criteria

- `Block.new(id: "ASCII", name: "Basic Latin", range_first: 0, range_last: 127,
  plane_number: 0)` serializes with the original ID preserved.
- Reading back the JSON yields an equal Block instance.
- No codepoint data is duplicated into Block/Script/Plane — only IDs.

## Architectural notes

- **SSOT**: block metadata lives in `output/blocks/<ID>.json` (TODO 28). CodePoint
  references block by ID only.
- **Original names**: per user decision (2026-06-25), `Blocks.txt` IDs are used verbatim.
  The wire shape's `id` field is exactly what `Blocks.txt` emits.
