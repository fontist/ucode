# frozen_string_literal: true

module Ucode
  module Commands
    # `ucode audit *` command classes. Pure Ruby — Thor (in
    # `lib/ucode/cli.rb`) is responsible only for argument parsing
    # and dispatch. Each class here is a structured-result command
    # that delegates to the {Ucode::Audit} pipeline
    # ({Audit::FaceAuditor}, {Audit::LibraryAuditor}, {Audit::Differ},
    # {Audit::Emitter::FaceDirectory}, {Audit::Browser::*}).
    module Audit
      autoload :FontCommand,       "ucode/commands/audit/font_command"
      autoload :CollectionCommand, "ucode/commands/audit/collection_command"
      autoload :LibraryCommand,    "ucode/commands/audit/library_command"
      autoload :CompareCommand,    "ucode/commands/audit/compare_command"
      autoload :BrowserCommand,    "ucode/commands/audit/browser_command"
      autoload :ReferenceBuilder,  "ucode/commands/audit/reference_builder"
    end
  end
end
