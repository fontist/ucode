# TODO 08 — Full spec coverage

## Status

Pending. Depends on TODOs 01-07.

## Context

Every public method in the `Ucode::Unicode` namespace must have specs.
No doubles — real Structs and real Catalog instances. No private send —
test through the public interface only.

## Files

- `spec/ucode/unicode/unicode_spec.rb` — namespace hub + version normalization
- `spec/ucode/unicode/plane_spec.rb` — Plane value object
- `spec/ucode/unicode/block_spec.rb` — Block value object
- `spec/ucode/unicode/catalog_spec.rb` — Catalog queries (the main spec)
- `spec/ucode/unicode/metadata_writer_spec.rb` — generator logic

## Spec outline

### `unicode_spec.rb`

```ruby
RSpec.describe Ucode::Unicode do
  describe "::SUPPORTED_VERSIONS" do
    it "includes 15.0.0, 15.1.0, 16.0.0, 17.0.0"
    it "is frozen"
  end

  describe "::LATEST_VERSION" do
    it "returns the newest supported version"
  end

  describe ".for_version" do
    it "accepts full version strings (17.0.0)"
    it "normalizes short forms (17 → 17.0.0)"
    it "normalizes partial forms (16.0 → 16.0.0)"
    it "raises UnknownUnicodeVersionError for unsupported versions"
    it "defaults to LATEST_VERSION when called with no args"
    it "returns a Catalog bound to the requested version"
  end

  describe ".assigned_count" do
    it "delegates to the latest version's catalog"
  end
end
```

### `plane_spec.rb`

```ruby
RSpec.describe Ucode::Unicode::Plane do
  it "is a keyword-init Struct"
  it "#cover? returns true for codepoints in range"
  it "#cover? returns false for codepoints outside range"
  it "is frozen after construction"
end
```

### `block_spec.rb`

```ruby
RSpec.describe Ucode::Unicode::Block do
  it "is a keyword-init Struct"
  it "#range returns first_cp..last_cp"
  it "#cover? returns true for codepoints in range"
  it "derives plane_number from first_cp"
end
```

### `catalog_spec.rb` (the main spec — ~25 examples)

```ruby
RSpec.describe Ucode::Unicode::Catalog do
  let(:catalog) { described_class.new(version: "17.0.0") }

  describe "#version" do
    it "returns the version string"
  end

  describe "#assigned_count" do
    it "returns a positive integer"
    it "matches DerivedGeneralCategory count minus Co/Cs"
  end

  describe "#assigned_in_plane" do
    it "returns assigned count for plane 0 (BMP)"
    it "returns assigned count for plane 1 (SMP)"
    it "returns 0 for unassigned planes (4-13)"
  end

  describe "#find_plane" do
    it "returns the BMP for number 0"
    it "returns nil for invalid plane numbers"
  end

  describe "#find_plane_by_codepoint" do
    it "returns BMP for U+0041"
    it "returns SMP for U+1F600"
    it "returns SIP for U+20000"
  end

  describe "#find_block" do
    it "finds by id 'Basic_Latin'"
    it "returns nil for unknown block id"
  end

  describe "#find_block_by_codepoint" do
    it "finds Basic_Latin for U+0041"
    it "finds CJK_Unified_Ideographs for U+4E00"
    it "returns nil for unassigned codepoints in gaps"
  end

  describe "#blocks_in_plane" do
    it "returns all blocks in plane 0 sorted by first_cp"
    it "returns empty array for plane 5 (unassigned)"
  end

  describe "#all_blocks" do
    it "returns ~346 blocks for Unicode 17.0.0"
    it "every block has a unique id"
  end

  describe "#all_planes" do
    it "returns 17 planes"
    it "plane numbers are 0..16"
  end

  describe "version specificity" do
    it "Unicode 16.0.0 has fewer blocks than 17.0.0"
    it "Unicode 15.0.0 has a different assigned_count than 17.0.0"
  end
end
```

### `metadata_writer_spec.rb`

```ruby
RSpec.describe Ucode::Unicode::MetadataWriter do
  # Uses fixture UCD slices (committed under spec/fixtures/ucd/)
  it "generates valid Ruby that passes ruby -c"
  it "includes the auto-generation header"
  it "computes ASSIGNED_COUNT from DerivedGeneralCategory"
  it "excludes Co and Cs from ASSIGNED_COUNT"
  it "includes all 17 planes"
  it "includes all blocks from Blocks.txt"
  it "is idempotent (same input → same output)"
end
```

## Acceptance criteria

- All spec files pass with 0 failures
- No `double()` anywhere — use real Structs/Catalog instances
- No `send(:private_method)` — test through public interface
- Coverage > 95% for `lib/ucode/unicode/`
- Specs exercise multiple Unicode versions (not just 17.0.0)
