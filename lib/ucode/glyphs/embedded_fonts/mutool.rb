# frozen_string_literal: true

require "open3"

require "ucode/error"

module Ucode
  module Glyphs
    module EmbeddedFonts
      # Subprocess boundary for `mutool` (mupdf-tools).
      #
      # Every `mutool info|show|draw|trace` invocation in
      # {EmbeddedFonts} goes through one of the four subcommand
      # classes below. Each class builds the right argv, delegates
      # the actual exec to a `runner` (injectable for tests), and
      # raises {MutoolError} on non-zero exit.
      #
      # Production code passes no `runner:` — the default
      # {SystemRunner} calls `Open3.capture3`. Specs inject a
      # {StubRunner} that returns canned outputs keyed by argv.
      #
      # Splitting the subprocess seam out of {PdfIndexer},
      # {CodepointMapper}, and {TraceRunner} makes those classes
      # unit-testable without a real `mutool` binary on PATH.
      module Mutool
        autoload :Info, "ucode/glyphs/embedded_fonts/mutool/info"
        autoload :Show, "ucode/glyphs/embedded_fonts/mutool/show"
        autoload :Draw, "ucode/glyphs/embedded_fonts/mutool/draw"
        autoload :Trace, "ucode/glyphs/embedded_fonts/mutool/trace"

        # Real subprocess runner — the production default.
        class SystemRunner
          # @param argv [Array<String>]
          # @return [String] combined stdout+stderr (matches mutool's
          #   convention of writing trace output to stderr and
          #   status to stdout)
          # @raise [MutoolError] on non-zero exit
          def run(*argv)
            out, err, status = Open3.capture3(*argv)
            return out + err if status.success?

            raise Ucode::MutoolError.new(
              "mutool failed (exit #{status.exitstatus}): #{err.strip}",
              context: { argv: argv },
            )
          end
        end

        # Test double — not an RSpec double. Returns canned outputs
        # keyed by an argv signature. Real class, real method, no
        # reflection magic. Lives in production code so any spec can
        # `Mutool::StubRunner.new(...)` it without loading spec
        # helpers.
        class StubRunner
          # @param responses [Hash{Array<String> => String}] keyed by
          #   argv signature. The signature is built by {#signature}
          #   so test code doesn't have to remember argv ordering.
          #   Pass `:raise` as the value to raise {MutoolError}.
          def initialize(responses: {})
            @responses = responses
          end

          # @param argv [Array<String>]
          def run(*argv)
            value = @responses.fetch(signature(argv)) do
              raise KeyError,
                    "StubRunner: no canned response for #{argv.inspect}. " \
                    "Known: #{@responses.keys.inspect}"
            end

            return value unless value == RAISE_SENTINEL

            raise Ucode::MutoolError.new(
              "stubbed failure for #{argv.inspect}",
              context: { argv: argv },
            )
          end

          RAISE_SENTINEL = Object.new.freeze
          private_constant :RAISE_SENTINEL

          private

          # Signature: [subcommand, *non_option_args, *option_flags]
          # ignores ordering of options but preserves positional args.
          # Tests construct keys via {StubRunner.signature}.
          def signature(argv)
            self.class.signature(argv)
          end

          def self.signature(argv)
            subcommand = argv.first
            positionals, options = argv.drop(1).partition do |a|
              !a.start_with?("-")
            end
            [subcommand, *positionals, *options.sort]
          end
        end
      end
    end
  end
end
