# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"

RSpec.describe Ucode::Glyphs::EmbeddedFonts::PdfSource do
  let(:tmp_root) { Pathname.new(Dir.mktmpdir) }
  let(:pdf_path) { tmp_root.join("CodeCharts.pdf") }

  before do
    # mutool only needs the file to exist; contents don't matter for
    # Source's job of resolving paths.
    File.write(pdf_path, "dummy")
  end

  after { safe_remove(tmp_root) }

  describe "PDF resolution" do
    it "uses the explicit :pdf argument when given" do
      src = described_class.new(pdf: pdf_path, cache_dir: tmp_root.join("cache"))
      expect(src.pdf_path).to eq(pdf_path)
    end

    it "uses UCODE_CODE_CHARTS_PDF env var when :pdf is nil" do
      src = described_class.new(
        env: { "UCODE_CODE_CHARTS_PDF" => pdf_path.to_s },
        cache_dir: tmp_root.join("cache"),
      )
      expect(src.pdf_path).to eq(pdf_path)
    end

    it "falls back to <gem_root>/CodeCharts.pdf" do
      src = described_class.new(
        cache_dir: tmp_root.join("cache"),
        gem_root: tmp_root,
      )
      expect(src.pdf_path).to eq(tmp_root.join("CodeCharts.pdf"))
    end

    it "raises EmbeddedFontsMissingError when the resolved PDF doesn't exist" do
      expect do
        described_class.new(pdf: tmp_root.join("missing.pdf"), cache_dir: tmp_root.join("cache"))
      end.to raise_error(Ucode::EmbeddedFontsMissingError)
    end
  end

  describe "cache resolution" do
    it "creates the cache directory if it doesn't exist" do
      cache = tmp_root.join("new_cache")
      expect(cache.exist?).to be(false)
      described_class.new(pdf: pdf_path, cache_dir: cache)
      expect(cache.exist?).to be(true)
    end

    it "uses UCODE_PDF_FONT_CACHE env var when :cache_dir is nil" do
      cache = tmp_root.join("env_cache")
      src = described_class.new(
        pdf: pdf_path,
        env: { "UCODE_PDF_FONT_CACHE" => cache.to_s },
      )
      expect(src.cache_dir).to eq(cache)
      expect(cache.exist?).to be(true)
    end
  end

  describe "#font_cache_path" do
    it "joins base font name and extension under cache_dir" do
      src = described_class.new(pdf: pdf_path, cache_dir: tmp_root.join("cache"))
      path = src.font_cache_path("CIAIIP+Uni2000Generalpunctuation", ".ttf")
      expect(path).to eq(tmp_root.join("cache", "CIAIIP+Uni2000Generalpunctuation.ttf"))
    end
  end
end
