# frozen_string_literal: true

require "spec_helper"
require "support/fake_http_server"
require "tmpdir"
require "pathname"
require "fileutils"
require "ucode/fetch/http"

RSpec.describe Ucode::Fetch::CodeCharts do
  let(:version) { "17.0.0" }
  let(:workdir) { Pathname.new(Dir.mktmpdir("ucode-fetch-charts-")) }
  let(:server) { FakeHttpServer.new }
  let(:charts_base_url) { "http://127.0.0.1:#{server.port}" }

  let(:pdf_body) { "%PDF-1.5\n%\xC3\xA4\xC3\xB6\xC3\xBC\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF\n" }

  let(:original_config) do
    {
      cache_root: Ucode.configuration.cache_root,
      charts_base_url: Ucode.configuration.charts_base_url,
      http_retries: Ucode.configuration.http_retries,
    }
  end

  before do
    Ucode.configuration.cache_root = workdir
    Ucode.configuration.charts_base_url = charts_base_url
    Ucode.configuration.http_retries = 0
  end

  after do
    o = original_config
    Ucode.configuration.cache_root = o[:cache_root]
    Ucode.configuration.charts_base_url = o[:charts_base_url]
    Ucode.configuration.http_retries = o[:http_retries]
    server.shutdown
    safe_remove(workdir) if workdir.exist?
  end

  describe ".call" do
    it "downloads a PDF and validates content-type + magic bytes" do
      # 0x10920 > 0xFFFF, so hex_pad produces "U10920.pdf"
      server.respond_with(
        "http://127.0.0.1:#{server.port}/charts/U10920.pdf",
        pdf_body,
        headers: { "Content-Type" => "application/pdf" },
      )

      count = described_class.call(version, block_first_cps: [0x10920])
      expect(count).to eq(1)

      pdf_path = Ucode::Cache.pdfs_dir(version).join("U10920.pdf")
      expect(pdf_path.exist?).to be(true)
      expect(pdf_path.read).to eq(pdf_body)
    end

    it "raises CodeChartNotFoundError when Content-Type is not application/pdf" do
      # 0x40 = 64, < 0xFFFF, so hex_pad produces "U0040.pdf" (4 chars)
      server.respond_with(
        "http://127.0.0.1:#{server.port}/charts/U0040.pdf",
        "<html>not found</html>",
        headers: { "Content-Type" => "text/html" },
      )

      expect do
        described_class.call(version, block_first_cps: [0x40])
      end.to raise_error(Ucode::CodeChartNotFoundError) do |err|
        expect(err.context[:content_type]).to eq("text/html")
      end
    end

    it "raises CodeChartNotFoundError when body lacks %PDF magic" do
      # 0x9999 = 39321, < 0xFFFF, so hex_pad produces "U9999.pdf" (4 chars)
      server.respond_with(
        "http://127.0.0.1:#{server.port}/charts/U9999.pdf",
        "this is not a PDF at all",
        headers: { "Content-Type" => "application/pdf" },
      )

      expect do
        described_class.call(version, block_first_cps: [0x9999])
      end.to raise_error(Ucode::CodeChartNotFoundError) do |err|
        expect(err.message).to include("magic")
      end
    end
  end

  describe Ucode::Fetch::Http do
    it "skips validation when validate: nil" do
      server.respond_with(
        "http://127.0.0.1:#{server.port}/anywhere.html",
        "<html>ok</html>",
        headers: { "Content-Type" => "text/html" },
      )
      Dir.mktmpdir do |tmp|
        dest = Pathname.new(tmp).join("x.html")
        expect do
          described_class.get(
            "http://127.0.0.1:#{server.port}/anywhere.html",
            dest: dest, validate: nil,
          )
        end.not_to raise_error
        expect(dest.read).to eq("<html>ok</html>")
      end
    end
  end
end
