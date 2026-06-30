# frozen_string_literal: true

require "socket"
require "pathname"

# In-process single-shot HTTP server for specs that need to test
# `Ucode::Fetch::Http.get` against crafted responses (e.g. validating
# Content-Type or %PDF magic bytes).
#
# Each test registers URL → (body, headers) routes via `respond_with`.
# Lives in `spec/support/` (not inside a `describe` block) so it
# doesn't trip RuboCop's leaky-constant-declaration rule.
class FakeHttpServer
  def initialize
    @port = bind_port
    @routes = {}
    @thread = Thread.new { serve }
  end

  attr_reader :port

  def respond_with(url, body, headers: {})
    @routes[url] = [body, headers]
  end

  def shutdown
    @thread.kill
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
    @server = TCPServer.new("127.0.0.1", @port)
    loop do
      client = @server.accept
      handle_request(client)
    rescue StandardError
      # client gone, ignore
    ensure
      client&.close
    end
  end

  def handle_request(client)
    request = +""
    while (line = client.gets) && line != "\r\n"
      request << line
    end
    path = request.split(" ", 3)[1] || "/"
    body, headers = route_for(path)
    write_response(client, body, headers)
  end

  def route_for(path)
    url_match = @routes.keys.find { |u| u.end_with?(path) }
    url_match ? @routes[url_match] : ["nope", { "Content-Type" => "text/plain" }]
  end

  def write_response(client, body, headers)
    client.write("HTTP/1.1 200 OK\r\n")
    client.write("Content-Length: #{body.bytesize}\r\n")
    headers.each { |k, v| client.write("#{k}: #{v}\r\n") }
    client.write("\r\n")
    client.write(body)
  end
end
