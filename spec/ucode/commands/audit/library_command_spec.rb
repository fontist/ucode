# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Ucode::Commands::Audit::LibraryCommand do
  let(:library) { "spec/fixtures/fonts" }
  let(:root)    { Dir.mktmpdir("ucode-audit-library-cmd") }

  after { safe_remove(root) if File.exist?(root) }

  it "audits every font under the directory (recursive)" do
    result = described_class.new.call(library, recursive: true,
                                               output_root: root, brief: true)
    expect(result.error).to be_nil
    expect(result.total_faces).to be > 1
    expect(result.total_files).to eq(result.total_faces)
    expect(File.exist?(File.join(root, "font_audit", "index.json"))).to be(true)
  end

  it "writes one index.json per face" do
    described_class.new.call(library, recursive: true, output_root: root, brief: true)
    faces = Dir.children(File.join(root, "font_audit")).select do |d|
      File.directory?(File.join(root, "font_audit", d))
    end
    indexed = faces.select { |d| File.exist?(File.join(root, "font_audit", d, "index.json")) }
    expect(indexed.length).to eq(faces.length)
  end

  it "writes the library-level HTML browser when browse: true" do
    described_class.new.call(library, recursive: true, output_root: root,
                                      brief: true, browse: true)
    html = File.join(root, "font_audit", "index.html")
    expect(File.exist?(html)).to be(true)
    expect(File.read(html)).to include("library-overview")
  end

  it "skips non-font files silently and reports zero skipped for the fixtures" do
    result = described_class.new.call(library, recursive: true,
                                               output_root: root, brief: true)
    expect(result.skipped).to eq([])
  end
end
