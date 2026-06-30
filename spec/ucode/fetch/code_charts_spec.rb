# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "pathname"
require "fileutils"
require "socket"
require "ucode/fetch/http"

RSpec.describe Ucode::Fetch::CodeCharts do
  let(:version) { "17.0.0" }
  let(:workdir) { Pathname.new(Dir.mktmpdir("ucode-fetch-charts-")) }

  # In-process single-shot HTTP server. Each test registers routes
  # via `respond_with(url, body, headers:)`; the server replies with
  # the registered payload. No doubles — this is real TCP/HTTP.
  class FakeServer
    def initialize
      @port = bind_port
      @routes = {}
      @thread = Thread.new { serve }
    end

    def port = @port

    def respond_with(url, body, headers: {})
      @routes[url] = [body, headers]
    end

    def shutdown
      @thread.kill rescue nil
      @server&.close
    end

    private

    def bind_port
      server = TCPServer.new("127.0.0.1", 0)
      port = server.addr[1]
      server.close
      port
    end

    def serve
      server = TCPServer.new("127.0.0.1", @port)
      @server = server
      loop do
        client = server.accept
        request = +""
        while (line = client.gets) && line != "\r\n"
          request << line
        end
        path = request.split(" ", 3)[1] || "/"
        url_match = @routes.keys.find { |u| u.end_with?(path) }
        body, headers = url_match ? @routes[url_match] : ["nope", { "Content-Type" => "text/plain" }]
        client.write("HTTP/1.1 200 OK\r\n")
        client.write("Content-Length: #{body.bytesize}\r\n")
        headers.each { |k, v| client.write("#{k}: #{v}\r\n") }
        client.write("\r\n")
        client.write(body)
      rescue StandardError
        # client gone, ignore
      ensure
        client&.close
      end
    end
  end

  let(:server) { FakeServer.new }
  let(:charts_base_url) { "http://127.0.0.1:#{server.port}" }

  let(:pdf_body) { "%PDF-1.5\n%\xC3\xA4\xC3\xB6\xC3\xBC\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF\n" }

  before do
    @original_root = Ucode.configuration.cache_root
    @original_base = Ucode.configuration.charts_base_url
    Ucode.configuration.cache_root = workdir
    Ucode.configuration.charts_base_url = charts_base_url
    @original_retries = Ucode.configuration.http_retries
    Ucode.configuration.http_retries = 0
  end

  after do
    Ucode.configuration.cache_root = @original_root
    Ucode.configuration.charts_base_url = @original_base
    Ucode.configuration.http_retries = @original_retries
    server.shutdown
    FileUtils.remove_entry(workdir) if workdir.exist?
  end

  describe ".call" do
    it "downloads a PDF and validates content-type + magic bytes" do
      # 0x10920 > 0xFFFF, so hex_pad produces "U010920.pdf"
      server.respond_with(
        "http://127.0.0.1:#{server.port}/charts/U010920.pdf",
        pdf_body,
        headers: { "Content-Type" => "application/pdf" },
      )

      count = described_class.call(version, block_first_cps: [0x10920])
      expect(count).to eq(1)

      pdf_path = Ucode::Cache.pdfs_dir(version).join("U010920.pdf")
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

      expect {
        described_class.call(version, block_first_cps: [0x40])
      }.to raise_error(Ucode::CodeChartNotFoundError) do |err|
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

      expect {
        described_class.call(version, block_first_cps: [0x9999])
      }.to raise_error(Ucode::CodeChartNotFoundError) do |err|
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
        expect {
          described_class.get(
            "http://127.0.0.1:#{server.port}/anywhere.html",
            dest: dest, validate: nil,
          )
        }.not_to raise_error
        expect(dest.read).to eq("<html>ok</html>")
      end
    end
  end
end