# frozen_string_literal: true

module Ucode
  module CodeChart
    class Verifier
      # Selects a {Strategy} based on tool availability. Preference
      # order:
      #
      #   1. `UCODE_VERIFIER_STRATEGY` env var override — explicit
      #      user choice. Value is the strategy class name (e.g.
      #      `"resvg"`, `"mutool"`).
      #   2. {ResvgStrategy} — preferred for accuracy and speed.
      #   3. {MutoolStrategy} — fallback (always installed if the
      #      trace pipeline works).
      #
      # Returns nil when no strategy is available; {Verifier} then
      # emits `Skipped` for every glyph.
      module Builder
        ORDER = %w[resvg mutool].freeze
        private_constant :ORDER

        class << self
          # @param strategies [Array<Strategy>, nil] injectable list
          #   for tests. nil = construct the default chain.
          # @return [Strategy, nil]
          def pick(strategies: nil)
            strategies ||= default_strategies
            env_choice = ENV["UCODE_VERIFIER_STRATEGY"]
            if env_choice
              found = strategies.find { |s| name_of(s) == env_choice }
              return found if found&.available?
            end
            strategies.find(&:available?)
          end

          private

          def default_strategies
            [ResvgStrategy.new, MutoolStrategy.new]
          end

          def name_of(strategy)
            strategy.class.name.split("::").last.sub("Strategy", "").downcase
          end
        end
      end
    end
  end
end
