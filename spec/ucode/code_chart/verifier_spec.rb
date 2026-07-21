# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "pathname"

require "ucode/code_chart/verifier/strategy"
require "ucode/code_chart/verifier/result"

# Real stub Strategy (not a double) that records calls and returns
# canned diff values. Lets the spec exercise the Verifier's
# orchestration logic without invoking any real CLI tool.
class StubVerifierStrategy < Ucode::CodeChart::Verifier::Strategy
  attr_reader :calls, :diff_value

  def initialize(diff_value: 0.0)
    super()
    @diff_value = diff_value
    @calls = []
  end

  def available? = true

  def render_svg(svg_path, png_path, scale: 2.0)
    @calls << [:render_svg, svg_path.to_s, png_path.to_s, scale]
    Pathname.new(png_path).write("FAKE PNG")
    Pathname.new(png_path)
  end

  def render_pdf_region(pdf_path, page, rect, png_path, **_scale)
    @calls << [:render_pdf_region, pdf_path.to_s, page, rect, png_path.to_s]
    Pathname.new(png_path).write("FAKE PDF PNG")
    Pathname.new(png_path)
  end

  def diff(_png_a, _png_b)
    diff_value
  end

  def write_diff_artifact(png_a, png_b, dest)
    Pathname.new(dest).write("#{png_a}+#{png_b}")
    Pathname.new(dest)
  end
end

RSpec.describe Ucode::CodeChart::Verifier do
  let(:tmpdir) { Pathname.new(Dir.mktmpdir("ucode-verifier-")) }
  let(:diff_dir) { tmpdir.join("diff") }

  let(:pdf_path) { tmpdir.join("test.pdf") }
  let(:pdf_bytes) { "%PDF-1.5\n...\n%%EOF\n" }

  let(:pass_result) do
    Ucode::CodeChart::Extractor::Result.new(
      codepoint: 0x10D40,
      svg: "<svg/>",
      tier: :pillar1,
      provenance: "pillar-1:embedded-tounicode",
      base_font: "ABC+Test",
      gid: 100,
      source_page: 2,
      source_cell: { x: 100.0, y: 200.0 },
    )
  end

  before do
    pdf_path.write(pdf_bytes)
  end

  after { safe_remove(tmpdir) if tmpdir.exist? }

  describe "#available?" do
    it "is true when a strategy is provided" do
      v = described_class.new(strategy: StubVerifierStrategy.new,
                              diff_dir: diff_dir)
      expect(v).to be_available
    end
  end

  describe "#verify" do
    it "returns Pass when diff is below threshold" do
      strategy = StubVerifierStrategy.new(diff_value: 0.5)
      v = described_class.new(strategy: strategy, diff_dir: diff_dir,
                              threshold: 1.0)
      result = v.verify(pass_result, pdf_path: pdf_path)
      expect(result).to be_a(Ucode::CodeChart::Verifier::Result::Pass)
      expect(result.codepoint).to eq(0x10D40)
      expect(result.percent).to eq(0.5)
    end

    it "returns Fail when diff is at or above threshold" do
      strategy = StubVerifierStrategy.new(diff_value: 5.0)
      v = described_class.new(strategy: strategy, diff_dir: diff_dir,
                              threshold: 1.0)
      result = v.verify(pass_result, pdf_path: pdf_path)
      expect(result).to be_a(Ucode::CodeChart::Verifier::Result::Fail)
      expect(result.percent).to eq(5.0)
      expect(result.diff_path).to exist
    end

    it "writes the diff artifact on Fail" do
      strategy = StubVerifierStrategy.new(diff_value: 5.0)
      v = described_class.new(strategy: strategy, diff_dir: diff_dir,
                              threshold: 1.0)
      result = v.verify(pass_result, pdf_path: pdf_path)
      expected = diff_dir.join("U+10D40.diff.png")
      expect(result.diff_path).to eq(expected)
      expect(expected).to exist
    end

    it "returns Skipped(:no_location) when source_page/source_cell are nil" do
      no_loc = Ucode::CodeChart::Extractor::Result.new(
        codepoint: 0x10D40, svg: "<svg/>", tier: :pillar3,
        provenance: "pillar-3:last-resort",
      )
      v = described_class.new(strategy: StubVerifierStrategy.new,
                              diff_dir: diff_dir)
      result = v.verify(no_loc, pdf_path: pdf_path)
      expect(result).to be_a(Ucode::CodeChart::Verifier::Result::Skipped)
      expect(result.reason).to eq(:no_location)
    end

    it "returns Skipped(:no_pdf) when the PDF path doesn't exist" do
      v = described_class.new(strategy: StubVerifierStrategy.new,
                              diff_dir: diff_dir)
      result = v.verify(pass_result, pdf_path: tmpdir.join("missing.pdf"))
      expect(result).to be_a(Ucode::CodeChart::Verifier::Result::Skipped)
      expect(result.reason).to eq(:no_pdf)
    end

    it "returns Skipped(:no_strategy) when no strategy was provided/available" do
      described_class.new(strategy: nil, diff_dir: diff_dir)
      # Builder.pick returns nil when no tools available; emulate by
      # passing a strategy-less instance directly. The constructor
      # runs Builder.pick by default, so to force nil we pass an
      # explicit nil strategy via an instance that skipped the
      # builder. Constructor falls back to Builder.pick; this test
      # validates behavior when strategy is genuinely nil by
      # stubbing Builder.pick.
      allow(Ucode::CodeChart::Verifier::Builder).to receive(:pick)
        .and_return(nil)
      v = described_class.new(diff_dir: diff_dir)
      result = v.verify(pass_result, pdf_path: pdf_path)
      expect(result).to be_a(Ucode::CodeChart::Verifier::Result::Skipped)
      expect(result.reason).to eq(:no_strategy)
    end
  end

  describe "OCP — adding a strategy" do
    it "lets the caller inject any object that quacks like Strategy" do
      # Custom strategy subclass with its own canned behavior
      custom = Class.new(Ucode::CodeChart::Verifier::Strategy) do
        def available? = true

        def render_svg(_, png, **_)
          Pathname.new(png).write("X")
          self
        end

        def render_pdf_region(_, _, _, png, **_)
          Pathname.new(png).write("Y")
          self
        end

        def diff(_, _); 0.0; end
      end.new
      v = described_class.new(strategy: custom, diff_dir: diff_dir)
      result = v.verify(pass_result, pdf_path: pdf_path)
      expect(result).to be_a(Ucode::CodeChart::Verifier::Result::Pass)
    end
  end
end
