# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Ucode::Audit::Emitter::GlyphEmitter do
  let(:root)     { Dir.mktmpdir("ucode-glyph-emit") }
  let(:face_dir) { Ucode::Audit::Emitter::Paths.face_dir(root, "Mona") }

  after { FileUtils.remove_entry(root) if File.exist?(root) }

  describe "with the default resolver" do
    let(:emitter) { described_class.new }

    it "returns false (skips emission) when the resolver yields nil" do
      expect(emitter.emit(face_dir, 0x41)).to be(false)
    end

    it "writes nothing" do
      emitter.emit(face_dir, 0x41)
      expect(Dir.glob("#{face_dir}/glyphs/*.svg")).to be_empty
    end
  end

  describe "with a custom resolver" do
    let(:resolver) { ->(cp) { "<svg id='U+#{format('%04X', cp)}'/>" } }
    let(:emitter)  { described_class.new(glyph_resolver: resolver) }

    it "writes <face_dir>/glyphs/U+XXXX.svg with the resolved SVG" do
      emitter.emit(face_dir, 0x41)
      path = face_dir.join("glyphs", "U+0041.svg")
      expect(File.exist?(path)).to be(true)
      expect(File.read(path)).to eq("<svg id='U+0041'/>")
    end

    it "returns true on first write" do
      expect(emitter.emit(face_dir, 0x41)).to be(true)
    end

    it "returns false on idempotent re-write" do
      emitter.emit(face_dir, 0x41)
      expect(emitter.emit(face_dir, 0x41)).to be(false)
    end

    it "supports supplementary plane codepoints (5-digit form)" do
      emitter.emit(face_dir, 0x1F600)
      expect(File.exist?(face_dir.join("glyphs", "U+1F600.svg"))).to be(true)
    end

    it "returns false when resolver yields nil for a specific codepoint" do
      partial = ->(cp) { cp == 0x41 ? "<svg/>" : nil }
      partial_emitter = described_class.new(glyph_resolver: partial)
      expect(partial_emitter.emit(face_dir, 0x42)).to be(false)
      expect(Dir.glob("#{face_dir}/glyphs/*.svg")).to be_empty
    end
  end
end
