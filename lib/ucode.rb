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
