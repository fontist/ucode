# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Ucode::Glyphs::PageRenderer do
  describe ".all" do
    it "lists every known concrete renderer" do
      expect(described_class.all).to include(
        Ucode::Glyphs::MutoolRenderer,
        Ucode::Glyphs::Pdf2svgRenderer,
        Ucode::Glyphs::DvisvgmRenderer,
        Ucode::Glyphs::PdftocairoRenderer,
      )
    end

    it "is frozen" do
      expect(described_class.all).to be_frozen
    end
  end

  describe ".find" do
    it "resolves by symbol" do
      expect(described_class.find(:mutool)).to eq(Ucode::Glyphs::MutoolRenderer)
    end

    it "resolves by string" do
      expect(described_class.find("pdftocairo")).to eq(Ucode::Glyphs::PdftocairoRenderer)
    end

    it "returns nil for unknown names" do
      expect(described_class.find(:nonexistent)).to be_nil
    end
  end

  describe ".available" do
    it "returns only renderers whose binary is on PATH" do
      available = described_class.available
      # On the dev machine, at least pdftocairo is expected.
      expect(available).to all(be <= described_class)
    end
  end

  describe ".default" do
    it "returns the first available renderer" do
      if described_class.available.any?
        expect(described_class.default).to eq(described_class.available.first)
      end
    end

    it "is included in the registry" do
      default = described_class.default
      expect(described_class.all).to include(default) if default
    end
  end

  describe "interface" do
    it "every concrete renderer implements renderer_name, binary_name, build_command" do
      described_class.all.each do |renderer|
        expect(renderer.renderer_name).to be_a(Symbol)
        expect(renderer.binary_name).to be_a(Symbol).or(be_a(String))
        cmd = renderer.build_command(Pathname("/tmp/in.pdf"), 1, Pathname("/tmp/out.svg"))
        expect(cmd).to be_an(Array)
        expect(cmd).to all(be_a(String))
      end
    end

    it "every concrete renderer returns :svg for output_format" do
      described_class.all.each do |renderer|
        expect(renderer.output_format).to eq(:svg)
      end
    end

    it "build_command includes the binary name as argv[0]" do
      described_class.all.each do |renderer|
        cmd = renderer.build_command(Pathname("/tmp/in.pdf"), 1, Pathname("/tmp/out.svg"))
        expect(cmd.first).to eq(renderer.binary_name.to_s)
      end
    end

    it "build_command includes the input pdf path" do
      described_class.all.each do |renderer|
        cmd = renderer.build_command(Pathname("/tmp/in.pdf"), 7, Pathname("/tmp/out.svg"))
        expect(cmd).to include("/tmp/in.pdf")
      end
    end

    it "build_command includes the output svg path" do
      described_class.all.each do |renderer|
        cmd = renderer.build_command(Pathname("/tmp/in.pdf"), 1, Pathname("/tmp/out.svg"))
        expect(cmd).to include("/tmp/out.svg")
      end
    end

    it "build_command includes the page number as a string" do
      described_class.all.each do |renderer|
        cmd = renderer.build_command(Pathname("/tmp/in.pdf"), 42, Pathname("/tmp/out.svg"))
        expect(cmd.join(" ")).to include("42")
      end
    end
  end

  describe ".available?" do
    it "returns true for a binary that exists on PATH" do
      stub_binary(described_class, "ls")
      expect(described_class).to be_available
    end

    it "returns false for a binary that does not exist" do
      stub_binary(described_class, "ucode_nonexistent_binary_xyz_123")
      expect(described_class).not_to be_available
    end
  end

  describe ".render" do
    let(:fixture_pdf) do
      Pathname.new(File.expand_path("../../fixtures/pdfs/basic_latin.pdf", __dir__))
    end

    it "raises PdfRenderError when the binary is unavailable" do
      stub_binary(described_class, "ucode_nonexistent_binary_xyz_123")
      expect { described_class.render(fixture_pdf, 1, "/tmp/out.svg") }
        .to raise_error(Ucode::PdfRenderError, /not available/)
    end
  end

  def stub_binary(renderer, name)
    allow(renderer).to receive(:binary_name).and_return(name)
  end
end

RSpec.describe "concrete renderers", :integration do
  let(:fixture_pdf) do
    Pathname.new(File.expand_path("../../fixtures/pdfs/basic_latin.pdf", __dir__))
  end

  Ucode::Glyphs::PageRenderer.available.each do |renderer|
    describe renderer do
      it "renders the fixture page to SVG with vector paths (acceptance)" do
        Dir.mktmpdir do |dir|
          out = File.join(dir, "out.svg")
          result = renderer.render(fixture_pdf, 1, out)
          expect(result).to eq(:ok)
          expect(File.size(out)).to be > 0
          body = File.read(out)
          expect(body).to include("<svg")
          expect(body).to include("<path")
          expect(body).not_to include("<image") # no raster fallback
        end
      end
    end
  end
end

RSpec.describe Ucode::Glyphs::PdfFetcher do
  let(:version) { "17.0.0" }

  around do |example|
    Dir.mktmpdir do |cache_root|
      @cache_root = Pathname.new(cache_root)
      original = Ucode.configuration.cache_root
      Ucode.configuration.cache_root = @cache_root
      Ucode::Cache.ensure_version_dir!(version)
      begin
        example.run
      ensure
        Ucode.configuration.cache_root = original
      end
    end
  end

  describe "#fetch" do
    it "returns the cached PDF path when present" do
      pdfs_dir = Ucode::Cache.pdfs_dir(version)
      pdf = pdfs_dir.join("U0000.pdf")
      pdf.write("dummy pdf bytes")

      fetcher = described_class.new(version)
      expect(fetcher.fetch(block_first_cp: 0)).to eq(pdf)
    end

    it "hex-slugs the filename with 4 digits for BMP blocks" do
      pdfs_dir = Ucode::Cache.pdfs_dir(version)
      pdf = pdfs_dir.join("U0041.pdf")
      pdf.write("dummy")

      fetcher = described_class.new(version)
      path = fetcher.fetch(block_first_cp: 0x41)
      expect(path.basename.to_s).to eq("U0041.pdf")
    end

    it "hex-slugs with 6 digits for plane-1+ blocks" do
      pdfs_dir = Ucode::Cache.pdfs_dir(version)
      pdf = pdfs_dir.join("U1F600.pdf")
      pdf.write("dummy")

      fetcher = described_class.new(version)
      path = fetcher.fetch(block_first_cp: 0x1F600)
      expect(path.basename.to_s).to eq("U1F600.pdf")
    end

    it "downloads via Fetch::CodeCharts when missing" do
      fetcher = described_class.new(version)
      # Stub the Fetch::CodeCharts.call to write the expected file
      expect(Ucode::Fetch::CodeCharts).to receive(:call)
        .with(version, block_first_cps: [0x41])
        .and_wrap_original do |m, *args|
        pdfs_dir = Ucode::Cache.pdfs_dir(version)
        pdfs_dir.join("U0041.pdf").write("downloaded")
        1
      end

      path = fetcher.fetch(block_first_cp: 0x41)
      expect(path.basename.to_s).to eq("U0041.pdf")
      expect(path.read).to eq("downloaded")
    end

    it "falls back to nil when fetch fails and no monolith is configured" do
      fetcher = described_class.new(version)
      expect(Ucode::Fetch::CodeCharts).to receive(:call)
        .and_raise(Ucode::NetworkError.new("simulated 404"))

      path = fetcher.fetch(block_first_cp: 0x41)
      expect(path).to be_nil
    end

    it "does not swallow non-fetch errors" do
      fetcher = described_class.new(version)
      expect(Ucode::Fetch::CodeCharts).to receive(:call)
        .and_raise(NoMethodError.new("undefined method `call'"))

      expect { fetcher.fetch(block_first_cp: 0x41) }.to raise_error(NoMethodError)
    end
  end

  describe "#fetch monolith fallback", :integration do
    let(:monolith_path) do
      Pathname.new(File.expand_path("../../../CodeCharts.pdf", __dir__))
    end

    let(:blocks) do
      [
        Ucode::Models::Block.new(id: "Basic_Latin", name: "Basic Latin",
                                  range_first: 0x0000, range_last: 0x007F, plane_number: 0),
      ]
    end

    before do
      skip "CodeCharts.pdf not present" unless monolith_path.exist?
      skip "pdftk not installed" unless system("which pdftk > /dev/null 2>&1")
    end

    it "slices pages from CodeCharts.pdf when the per-block PDF is unavailable" do
      # Simulate network failure → fallback to monolith.
      expect(Ucode::Fetch::CodeCharts).to receive(:call)
        .and_raise(Ucode::NetworkError.new("simulated offline"))

      fetcher = described_class.new(version,
                                     monolith_path: monolith_path,
                                     blocks: blocks)
      path = fetcher.fetch(block_first_cp: 0x0000)
      expect(path).not_to be_nil
      expect(path.exist?).to be(true)
      expect(path.size).to be > 100_000  # real per-block PDFs are ~hundreds of KB
    end
  end
end
