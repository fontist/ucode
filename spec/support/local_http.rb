# frozen_string_literal: true

require "fileutils"
require "pathname"

# Real in-memory implementation of the HTTP protocol used by
# {Ucode::Fetch::SpecialistFontFetcher}. Writes local fixture bytes
# to the destination path; raises if the URL has no mapped source.
#
# Used in specs to test the fetcher without real network I/O. Not a
# double — this is a real class that satisfies the same `.get(url,
# dest:)` contract as {Ucode::Fetch::Http}.
class LocalHttp
  class MissingRoute < StandardError; end

  # @param routes [Hash{String=>String,Pathname}] url → local file
  #   whose bytes get copied on `get`.
  def initialize(routes = {})
    @routes = routes.transform_values { |v| Pathname.new(v) }
  end

  # @param url [String]
  # @param dest [String, Pathname]
  # @return [Pathname] destination
  def get(url, dest:, **)
    source = @routes[url]
    raise MissingRoute, "no LocalHttp route for #{url}" unless source&.exist?

    destination = Pathname.new(dest)
    destination.dirname.mkpath
    FileUtils.cp(source, destination)
    destination
  end

  # Register or replace a route at runtime (specs build fixtures
  # inside `before` blocks after the helper is constructed).
  def register(url, source_path)
    @routes[url] = Pathname.new(source_path)
  end
end
