# frozen_string_literal: true

module Ucode
  # Commands — one Thor class per CLI subcommand.
  #
  # Each command delegates the actual work to a `*Command::Action` (or
  # similar) structured-result class. The Thor method is purely dispatch
  # + formatting. This keeps Thor thin and the work testable in-process.
  module Commands
    autoload :FetchCommand, "ucode/commands/fetch"
    autoload :ParseCommand, "ucode/commands/parse"
    autoload :GlyphsCommand, "ucode/commands/glyphs"
    autoload :SiteCommand, "ucode/commands/site"
    autoload :LookupCommand, "ucode/commands/lookup"
    autoload :CacheCommand, "ucode/commands/cache"
    autoload :BuildCommand, "ucode/commands/build"
  end
end
