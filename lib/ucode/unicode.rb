# frozen_string_literal: true

module Ucode
  # Unicode metadata Ruby API.
  #
  # Provides version-specific access to plane, block, and assigned-codepoint
  # counts without requiring UCD text files at runtime. Metadata is shipped
  # as frozen Ruby constants (one module per Unicode version) so consumers
  # get O(1) lookup with no file I/O.
  #
  # Multiple Unicode versions are supported simultaneously — a consumer
  # auditing a Unicode 16.0 font queries v16 metadata while the gem also
  # ships v17 as the default.
  #
  # @example Default (latest version)
  #   Ucode::Unicode.assigned_count         # => 159_866
  #   Ucode::Unicode.find_block("Basic_Latin")
  #
  # @example Version-specific
  #   catalog = Ucode::Unicode.for_version("16.0")
  #   catalog.assigned_count                # => v16 count (different)
  #   catalog.find_plane_by_codepoint(0x41)
  #
  module Unicode
    SUPPORTED_VERSIONS = %w[17.0.0].freeze

    LATEST_VERSION = "17.0.0"

    # Official Unicode plane short names. Planes 4–13 are unassigned
    # and have no short name. Used by {Catalog} when building Plane
    # objects.
    PLANE_NAMES = {
      0 => { short_name: :BMP, display_name: "Basic Multilingual Plane" },
      1 => { short_name: :SMP, display_name: "Supplementary Multilingual Plane" },
      2 => { short_name: :SIP, display_name: "Supplementary Ideographic Plane" },
      3 => { short_name: :TIP, display_name: "Tertiary Ideographic Plane" },
      14 => { short_name: :SSP, display_name: "Supplementary Special-purpose Plane" },
      15 => { short_name: :"SPUA-A", display_name: "Supplementary Private Use Area-A" },
      16 => { short_name: :"SPUA-B", display_name: "Supplementary Private Use Area-B" },
    }.freeze

    autoload :Plane, "ucode/unicode/plane"
    autoload :Block, "ucode/unicode/block"
    autoload :Catalog, "ucode/unicode/catalog"

    module Metadata
      # V17_0_0 mirrors the dotted version; underscores are intentional
      # rubocop:disable Naming/VariableNumber
      autoload :V17_0_0, "ucode/unicode/metadata/v17_0_0"
      # rubocop:enable Naming/VariableNumber
    end

    class << self
      def for_version(version = LATEST_VERSION)
        Catalog.new(version: normalize_version(version))
      end

      def assigned_count
        for_version.assigned_count
      end

      def unicode_version
        LATEST_VERSION
      end

      private

      def normalize_version(input)
        parts = input.split(".")
        normalized = (parts + ["0", "0", "0"]).first(3).join(".")
        unless SUPPORTED_VERSIONS.include?(normalized)
          raise Ucode::UnknownUnicodeVersionError.new(
            "unsupported Unicode version #{input.inspect}",
            context: { version: input, supported: SUPPORTED_VERSIONS },
          )
        end
        normalized
      end
    end
  end
end
