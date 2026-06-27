# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Ucode::Commands::Audit::FontCommand do
  let(:fixture) { "spec/fixtures/fonts/MonaSans/MonaSans-Regular.otf" }
  let(:root)    { Dir.mktmpdir("ucode-audit-font-cmd") }

  after { FileUtils.remove_entry(root) if File.exist?(root) }

  it "writes a per-face directory under <root>/font_audit/<label>/" do
    result = described_class.new.call(fixture, output_root: root, brief: true)
    expect(result.error).to be_nil
    expect(result.label).to eq("MonaSans-Regular")
    face_dir = File.join(root, "font_audit", "MonaSans-Regular")
    expect(File.exist?(File.join(face_dir, "index.json"))).to be(true)
    expect(result.output_dir).to eq(face_dir)
  end

  it "writes the HTML browser when browse: true" do
    described_class.new.call(fixture, output_root: root, brief: true, browse: true)
    html = File.join(root, "font_audit", "MonaSans-Regular", "index.html")
    expect(File.exist?(html)).to be(true)
    expect(File.read(html)).to include("Mona Sans Regular")
  end

  it "omits the HTML browser when browse: false" do
    described_class.new.call(fixture, output_root: root, brief: true, browse: false)
    html = File.join(root, "font_audit", "MonaSans-Regular", "index.html")
    expect(File.exist?(html)).to be(false)
  end

  it "emits per-codepoint detail chunks when verbose: true" do
    described_class.new.call(fixture, output_root: root, verbose: true)
    cps_dir = File.join(root, "font_audit", "MonaSans-Regular", "codepoints")
    expect(Dir.exist?(cps_dir)).to be(true)
    expect(Dir.children(cps_dir).length).to be > 0
  end

  it "honors an explicit label override" do
    result = described_class.new.call(
      fixture, output_root: root, brief: true, label: "mona-test",
    )
    expect(result.label).to eq("mona-test")
    expect(File.exist?(File.join(root, "font_audit", "mona-test", "index.json"))).to be(true)
  end

  it "captures errors in the result struct rather than raising" do
    result = described_class.new.call(
      "/no/such/font.otf", output_root: root, brief: true, install: false,
    )
    expect(result.error).to include("Errno::ENOENT")
  end

  it "exposes per-face outcomes (label, postscript_name, output_dir)" do
    result = described_class.new.call(fixture, output_root: root, brief: true)
    expect(result.faces.length).to eq(1)
    face = result.faces.first
    expect(face.label).to eq("MonaSans-Regular")
    expect(face.postscript_name).to eq("MonaSans-Regular")
    expect(face.output_dir).to eq(File.join(root, "font_audit", "MonaSans-Regular"))
  end
end
