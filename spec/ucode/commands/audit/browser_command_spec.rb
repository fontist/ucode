# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Ucode::Commands::Audit::BrowserCommand do
  let(:library) { "spec/fixtures/fonts" }
  let(:root)    { Dir.mktmpdir("ucode-audit-browser-cmd") }
  let(:audit_root) { File.join(root, "font_audit") }

  before do
    # Audit without browse so HTML is absent, then verify BrowserCommand
    # regenerates it from JSON alone.
    Ucode::Commands::Audit::LibraryCommand.new.call(
      library, recursive: true, output_root: root, brief: true, browse: false,
    )
  end

  after { FileUtils.remove_entry(root) if File.exist?(root) }

  it "regenerates the library index.html from existing index.json" do
    html = File.join(audit_root, "index.html")
    expect(File.exist?(html)).to be(false)
    result = described_class.new.call(input: audit_root)
    expect(result.error).to be_nil
    expect(File.exist?(html)).to be(true)
    expect(File.read(html)).to include("library-overview")
  end

  it "regenerates each per-face index.html" do
    face_dirs = Dir.children(audit_root).select do |d|
      File.directory?(File.join(audit_root, d))
    end
    face_dirs.each do |d|
      html = File.join(audit_root, d, "index.html")
      expect(File.exist?(html)).to be(false)
    end

    result = described_class.new.call(input: audit_root)
    expect(result.faces.length).to eq(face_dirs.length)

    face_dirs.each do |d|
      html = File.join(audit_root, d, "index.html")
      expect(File.exist?(html)).to be(true), "#{html} missing after regen"
    end
  end

  it "does not touch JSON files during regeneration" do
    json_mtimes = Dir.glob(File.join(audit_root, "**", "index.json")).to_h do |f|
      [f, File.mtime(f)]
    end
    described_class.new.call(input: audit_root)
    json_mtimes.each do |f, mtime|
      expect(File.mtime(f)).to eq(mtime), "#{f} was rewritten"
    end
  end

  it "respects faces_only: true and skips the library page" do
    result = described_class.new.call(input: audit_root, faces_only: true)
    expect(result.library_html).to be_nil
    expect(result.faces.length).to be > 0
  end

  it "respects library_only: true and skips per-face pages" do
    result = described_class.new.call(input: audit_root, library_only: true)
    expect(result.library_html).not_to be_nil
    expect(result.faces).to eq([])
  end
end
