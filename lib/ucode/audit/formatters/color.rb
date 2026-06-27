# frozen_string_literal: true

module Ucode
  module Audit
    module Formatters
      # Minimal ANSI helper. Formatters route every color emphasis
      # through this module so the NO_COLOR env var is honored uniformly.
      #
      # Follows the no-color.org convention: when ENV["NO_COLOR"] is
      # set to any non-empty value, all color methods return the input
      # string unchanged.
      module Color
        RESET = "\e[0m"
        BOLD  = "\e[1m"
        DIM   = "\e[2m"
        RED   = "\e[31m"
        GREEN = "\e[32m"
        CYAN  = "\e[36m"

        module_function

        def enabled?
          ENV["NO_COLOR"].nil? || ENV["NO_COLOR"].empty?
        end

        def bold(text)
          enabled? ? "#{BOLD}#{text}#{RESET}" : text
        end

        def dim(text)
          enabled? ? "#{DIM}#{text}#{RESET}" : text
        end

        def cyan(text)
          enabled? ? "#{CYAN}#{text}#{RESET}" : text
        end

        def green(text)
          enabled? ? "#{GREEN}#{text}#{RESET}" : text
        end

        def red(text)
          enabled? ? "#{RED}#{text}#{RESET}" : text
        end
      end
    end
  end
end
