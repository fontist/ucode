# frozen_string_literal: true

require "logger"
require "pathname"
require "lutaml/model"

# ucode — Unicode Character Database toolkit.
#
# Top-level hub. Every namespace under Ucode has its own hub file at
# lib/ucode/<ns>.rb declaring autoloads for its children. This file
# autoloads those hubs plus the flat Ucode::* classes. Files are loaded
# lazily on first reference.
module Ucode
  autoload :VERSION, "ucode/version"

  # Foundation
  autoload :Config, "ucode/config"
  autoload :Error, "ucode/error"
  # Error subclasses are referenced independently of Ucode::Error in
  # rescue / raise clauses throughout the library. Declaring autoloads
  # for each ensures any one of them triggers the single load of
  # error.rb (which defines all of them in one pass).
  autoload :FetchError, "ucode/error"
  autoload :NetworkError, "ucode/error"
  autoload :ChecksumError, "ucode/error"
  autoload :ParseError, "ucode/error"
  autoload :MalformedLineError, "ucode/error"
  autoload :UnknownPropertyError, "ucode/error"
  autoload :LookupError, "ucode/error"
  autoload :DatabaseMissingError, "ucode/error"
  autoload :DatabaseSchemaError, "ucode/error"
  autoload :UnknownVersionError, "ucode/error"
  autoload :GlyphError, "ucode/error"
  autoload :PdfRenderError, "ucode/error"
  autoload :GridDetectionError, "ucode/error"
  autoload :LastResortMissingError, "ucode/error"
  autoload :EmbeddedFontsMissingError, "ucode/error"
  autoload :CodeChartNotFoundError, "ucode/error"

  # Infrastructure
  autoload :Cache, "ucode/cache"
  autoload :VersionResolver, "ucode/version_resolver"

  # Namespace hubs (each hub declares its own child autoloads)
  autoload :Fetch, "ucode/fetch"
  autoload :Models, "ucode/models"
  autoload :Parsers, "ucode/parsers"
  autoload :Coordinator, "ucode/coordinator"
  autoload :RangeEntry, "ucode/range_entry"
  autoload :Index, "ucode/index"
  autoload :Database, "ucode/database"
  autoload :DbBuilder, "ucode/db_builder"
  autoload :IndexBuilder, "ucode/index_builder"
  autoload :Aggregator, "ucode/aggregator"
  autoload :Repo, "ucode/repo"
  autoload :Glyphs, "ucode/glyphs"
  autoload :Audit, "ucode/audit"
  autoload :CodeChart, "ucode/code_chart"
  autoload :Site, "ucode/site"
  autoload :Commands, "ucode/commands"
  autoload :Cli, "ucode/cli"

  class << self
    # @return [Ucode::Config]
    def configuration
      @configuration ||= Config.new
    end

    # @yield [config]
    # @yieldparam config [Ucode::Config]
    # @return [void]
    def configure
      yield(configuration)
    end
  end
end
