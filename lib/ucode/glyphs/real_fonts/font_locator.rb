# frozen_string_literal: true

require "pathname"

require "fontist"

module Ucode
  module Glyphs
    module RealFonts
      # Resolves a user-provided font specifier to a concrete file
      # path on disk. Resolution order:
      #
      #   1. Direct file path — returns it if it exists. Useful for
      #      local checkouts (e.g. a developer's clone of Lentariso).
      #   2. `Fontist::Font.find(name)` — returns the already-installed
      #      font path if fontist has it on disk.
      #   3. `Fontist::Font.install(name)` — downloads + installs the
      #      font via the fontist formula index.
      #
      # Fontist is the canonical discovery layer for the fontist
      # ecosystem. We never reach into other package managers or
      # hardcode URLs here — formulas live in fontist/formulas.
      class FontLocator
        LocateResult = Struct.new(:name, :path, :via, keyword_init: true)

        # @param spec [String] either a file path or a fontist formula
        #   name (case-insensitive). A `name=path` form is also
        #   accepted so a CLI can name the font whatever the user
        #   wants without depending on the formula's family name.
        # @param install [Boolean] if true and the font is not on
        #   disk, attempt `Fontist::Font.install`. Default: true.
        # @return [LocateResult]
        # @raise [Errno::ENOENT] if path does not exist and fontist
        #   cannot resolve the name.
        def locate(spec, install: true)
          name, path = split_spec(spec)
          return result(name, path, :direct) if path && File.exist?(path)

          via_fontist = find_via_fontist(name, install: install)
          return via_fontist if via_fontist

          raise Errno::ENOENT, "Font not found: #{spec}"
        end

        private

        def split_spec(spec)
          if spec.include?("=")
            name, path = spec.split("=", 2)
            [name.strip, path]
          else
            [spec, spec]
          end
        end

        def find_via_fontist(name, install:)
          found = safe_fontist_lookup { Fontist::Font.find(name) }
          return result(name, found, :fontist_find) if found
          return nil unless install

          paths = install_via_fontist(name)
          return nil unless paths&.any?

          result(name, paths.first, :fontist_install)
        end

        def install_via_fontist(name)
          Fontist::Font.install(
            name,
            confirmation: "yes",
            hide_licenses: true,
          )
        rescue Fontist::Errors::UnsupportedFontError,
               Fontist::Errors::FontNotFoundError
          nil
        end

        # `Fontist::Font.find` raises `UnsupportedFontError` when the
        # name isn't in the formula index — that's a "not found"
        # outcome for our purposes, not an exceptional control-flow
        # event. Translate to nil so the caller can fall through to
        # the install-or-fail branch.
        def safe_fontist_lookup
          yield
        rescue Fontist::Errors::UnsupportedFontError, Fontist::Errors::FontNotFoundError
          nil
        end

        def result(name, path, via)
          LocateResult.new(name: name, path: Pathname(path), via: via)
        end
      end
    end
  end
end
