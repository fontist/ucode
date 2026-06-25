# 21. NamesList parser — state machine

**Goal**: Parse `NamesList.txt`, the human-curated annotated names file. Yields one
`NamesListEntry` (or its parts) per codepoint. This is the file that makes ucode valuable
for relationship discovery — it carries the prose cross-references ucdxml drops.

**Depends on**: 17.

**Files**:
- `lib/ucode/parsers/names_list.rb`
- `spec/ucode/parsers/names_list_spec.rb`
- `spec/fixtures/ucd/NamesList.txt` — sliced from the real file (Latin block + a few CJK +
  a few Arabic, covering every marker type).

## Tasks

- [ ] `NamesList.txt` format (from the file's own header):
  - Each line is either:
    - **Column 0 non-empty, not a known prefix** → `cp; Name` header (new codepoint).
    - **Column 0 empty, indented** → annotation belonging to the most recent header.
    - Lines starting with `#` → file-level comments (skip).
  - Annotation prefixes:
    - `→ ` → see-also cross-reference. Format: `→ U+XXXX note`
    - `× ` → sample sequence. Format: `× U+XXXX U+YYYY note (rendered: Á)`
    - `≡ ` → compatibility equivalent. Format: `≡ U+XXXX note`
    - `= ` → informal alias. Format: `= alias text`
    - `* ` → footnote. Format: `* footnote text`
    - `%` → instructional (DROP — not part of the dataset).
    - `~` → cross-reference heading (DROP — table-of-contents only).
- [ ] Implement as a small state machine:
  ```ruby
  class NamesList
    include Enumerable

    def initialize(path)
      @path = path
    end

    def each
      return enum_for(:each) unless block_given?
      current = nil
      File.foreach(@path, chomp: true) do |line|
        if header_line?(line)
          yield current if current
          current = NamesListEntry.new(cp: parse_cp(line))
        elsif annotation_line?(line)
          attach_annotation(current, line)
        end
        # else: blank, comment, or instructional — skip
      end
      yield current if current
    end
  end
  ```
- [ ] Yield `NamesListEntry` with separate typed arrays:
  - `cross_references: [CrossReference]` (one per `→` line)
  - `sample_sequences: [SampleSequence]` (one per `×` line)
  - `compatibility_equivalents: [CompatEquiv]`
  - `informal_aliases: [InformalAlias]`
  - `footnotes: [Footnote]` (each with optional `category` from line position / heuristic)
- [ ] Coordinator (TODO 25) merges these into `CodePoint.relationships` (the polymorphic
      collection), tagging each with `source: "names_list"`.

## Acceptance criteria

- Round-trip on a fixture covering every marker type.
- A single codepoint with 3 `→`, 1 `×`, 2 `*` annotations yields 1 NamesListEntry with
  exactly those counts.
- Instructional (`%`) and heading (`~`) lines are NOT emitted.
- Multi-line annotations (no, but verify — some NamesList annotations may wrap to
  continuation lines) are handled correctly. If continuation rules exist, document them.

## Architectural notes

- **State machine, not regex**: regex can't track "indented under which header".
- **Coordinator responsibility**: this parser yields NamesListEntry records; Coordinator
  flattens them into CodePoint.relationships arrays. The polymorphic Relationship
  subclasses come from TODO 14.
- **% and ~ are noise** — drop them. If we ever want them, add later (OCP: they don't
  block the main path).