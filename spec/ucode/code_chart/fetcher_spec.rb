# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "pathname"

# Real stub HTTP module. Records calls + writes a canned PDF body to
# the dest path. NOT an RSpec double — per project's no-doubles rule.
class StubHttp
  class NotFound < StandardError; end

  attr_reader :calls

  def initialize(body:, fail_with: nil)
    @body = body
    @fail_with = fail_with
    @calls = []
  end

  def get(url, dest:, validate: nil, not_found_class: nil, **_opts)
    @calls << { url: url, dest: dest, validate: validate }
    if @fail_with == :not_found
      raise not_found_class.new("HTTP 404", context: { url: url, status: 404 })
    end

    Pathname.new(dest).write(@body)
    Pathname.new(dest)
  end
end

RSpec.describe Ucode::CodeChart::Fetcher do
  let(:tmpdir) { Pathname.new(Dir.mktmpdir("ucode-fetcher-")) }
  let(:block) do
    Ucode::Models::Block.new(
      id: "Sidetic", name: "Sidetic",
      range_first: 0x10920, range_last: 0x1093F,
      plane_number: 1,
    )
  end
  let(:pdf_bytes) { "%PDF-1.5\n...\n%%EOF\n" }

  before do
    allow(Ucode::Cache).to receive(:pdfs_dir).and_return(tmpdir)
  end

  after { safe_remove(tmpdir) if tmpdir.exist? }

  describe "#fetch" do
    it "downloads the PDF on first call and writes a sha256 sidecar" do
      http = StubHttp.new(body: pdf_bytes)
      fetcher = described_class.new(version: "17.0.0", http: http)

      path = fetcher.fetch(block: block)
      expect(path).to exist
      sidecar = Pathname.new("#{path}.sha256")
      expect(sidecar).to exist
      expected = Digest::SHA256.file(path).hexdigest
      expect(sidecar.read.strip).to eq(expected)
    end

    it "uses the per-block URL slug (4-digit zero-padded hex of first cp)" do
      http = StubHttp.new(body: pdf_bytes)
      fetcher = described_class.new(version: "17.0.0", http: http)

      fetcher.fetch(block: block)
      expect(http.calls.first[:url])
        .to eq("https://www.unicode.org/charts/PDF/U10920.pdf")
    end

    it "is idempotent — cache hit makes no network call" do
      http = StubHttp.new(body: pdf_bytes)
      fetcher = described_class.new(version: "17.0.0", http: http)

      fetcher.fetch(block: block)
      fetcher.fetch(block: block)

      expect(http.calls.size).to eq(1)
    end

    it "raises CodeChartNotFoundError on HTTP 4xx" do
      http = StubHttp.new(body: pdf_bytes, fail_with: :not_found)
      fetcher = described_class.new(version: "17.0.0", http: http)

      expect { fetcher.fetch(block: block) }
        .to raise_error(Ucode::CodeChartNotFoundError, /HTTP 404/)
    end

    it "raises CodeChartChecksumError when the cached PDF is tampered" do
      http = StubHttp.new(body: pdf_bytes)
      fetcher = described_class.new(version: "17.0.0", http: http)

      path = fetcher.fetch(block: block)
      Pathname.new(path).write("tampered#{pdf_bytes}")

      expect { fetcher.fetch(block: block) }
        .to raise_error(Ucode::CodeChartChecksumError, /sha256 mismatch/)
    end
  end

  describe "#fetch_by_first_cp" do
    it "produces the same result as #fetch for the same block" do
      http = StubHttp.new(body: pdf_bytes)
      fetcher = described_class.new(version: "17.0.0", http: http)

      via_block = fetcher.fetch(block: block)
      http.calls.clear # reset to force re-download
      via_cp = fetcher.fetch_by_first_cp(block_first_cp: 0x10920,
                                         block_id: "Sidetic")
      expect(via_cp).to eq(via_block)
    end
  end
end
