# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    # One entry in `config/specialist_fonts.yml` — a Tier 1 font that
    # fontist's formula index does not carry (academic sites, SIL
    # downloads, GitHub releases). The fetcher walks a list of these
    # and materializes each `path` on disk.
    #
    # Wire shape (YAML):
    #
    #   label: Lentariso
    #   version: "1.033"
    #   license: OFL
    #   url: "https://github.com/.../Lentariso.otf"
    #   sha256: "<hex>"          # null until first successful fetch
    #   path: "data/fonts/Lentariso.otf"
    #   extract: false
    #   extract_member: null     # required when extract: true
    #   provenance: "Imperial Aramaic / Phoenician / Sidetic coverage"
    #
    # `url: null` marks a local-only entry: the user supplies the
    # file at `path` (which may use `~` and shell globs); the fetcher
    # never attempts a network download for these.
    class SpecialistFont < Lutaml::Model::Serializable
      LICENSE_OFL = "OFL"
      private_constant :LICENSE_OFL

      attribute :label, :string
      attribute :version, :string
      attribute :license, :string, default: -> { LICENSE_OFL }
      attribute :url, :string
      attribute :sha256, :string
      attribute :path, :string
      attribute :extract, :boolean, default: -> { false }
      attribute :extract_member, :string
      attribute :provenance, :string

      key_value do
        map "label", to: :label
        map "version", to: :version
        map "license", to: :license
        map "url", to: :url
        map "sha256", to: :sha256
        map "path", to: :path
        map "extract", to: :extract
        map "extract_member", to: :extract_member
        map "provenance", to: :provenance
      end

      def local_only?
        url.nil? || url.empty?
      end

      def ofl?
        license == LICENSE_OFL
      end

      def hash_known?
        !sha256.nil? && !sha256.empty?
      end

      def extract?
        extract == true
      end
    end
  end
end
