# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Ucode::Commands::Audit::CompareCommand do
  let(:left_path)  { "spec/fixtures/fonts/MonaSans/MonaSans-Regular.otf" }
  let(:right_path) { "spec/fixtures/fonts/NotoSansAdlam-Regular.ttf" }
  let(:root)       { Dir.mktmpdir("ucode-audit-compare-cmd") }

  after { FileUtils.remove_entry(root) if File.exist?(root) }

  it "diffs two fonts audited fresh on the fly" do
    result = described_class.new.call(left_path, right_path)
    expect(result.error).to be_nil
    expect(result.diff).to be_a(Ucode::Models::Audit::AuditDiff)
    expect(result.text).to include("AUDIT DIFF")
    expect(result.text).to include("FIELD CHANGES")
  end

  it "accepts a face audit directory on either side" do
    Ucode::Commands::Audit::FontCommand.new.call(left_path, output_root: root, brief: true)
    face_dir = File.join(root, "font_audit", "MonaSans-Regular")

    result = described_class.new.call(face_dir, right_path)
    expect(result.error).to be_nil
    # Both sides resolve to the font's source_file (absolute).
    expect(result.diff.left_source).to eq(File.expand_path(left_path))
    expect(result.diff.right_source).to eq(File.expand_path(right_path))
  end

  it "accepts an index.json path on either side" do
    Ucode::Commands::Audit::FontCommand.new.call(left_path, output_root: root, brief: true)
    index_json = File.join(root, "font_audit", "MonaSans-Regular", "index.json")

    result = described_class.new.call(index_json, right_path)
    expect(result.error).to be_nil
  end

  it "writes the text diff to a file when output_file: is set" do
    target = File.join(root, "diff.txt")
    described_class.new.call(left_path, right_path, output_file: target)
    expect(File.exist?(target)).to be(true)
    expect(File.read(target)).to include("AUDIT DIFF")
  end

  it "captures errors in the result struct" do
    result = described_class.new.call(left_path, "/no/such/font.ttf")
    expect(result.error).to match(/Errno::ENOENT|Fontisan|Fontist/)
  end
end
