# frozen_string_literal: true

require "spec_helper"
require "support/static_cmaps"
require "support/static_font_locator"
require "tmpdir"
require "fileutils"
require "yaml"

RSpec.describe Ucode::Glyphs::UniversalSet::PreBuildCheck do
  let(:workdir) { Pathname.new(Dir.mktmpdir("ucode-prebuild-")) }
  let(:db_path) { workdir.join("test.sqlite3") }
  let(:database) { build_database(db_path) }
  let(:cmaps) { StaticCmaps.new("lentariso" => [0x41, 0x42, 0x43]) }

  after { safe_remove(workdir) if workdir.exist? }

  def build_database(path)
    require "sqlite3"
    db = SQLite3::Database.new(path.to_s)
    db.execute "CREATE TABLE blocks (first_cp INTEGER, last_cp INTEGER, name TEXT)"
    db.execute "CREATE TABLE schema_meta (key TEXT PRIMARY KEY, value TEXT)"
    db.execute("INSERT INTO schema_meta (key, value) VALUES (?, ?)",
               ["ucd_version", "17.0.0"])
    db.execute("INSERT INTO schema_meta (key, value) VALUES (?, ?)",
               ["schema_version", Ucode::Database::SCHEMA_VERSION])
    db.execute("INSERT INTO blocks VALUES (65, 67, 'Basic_Latin')") # A, B, C
    db.execute("INSERT INTO blocks VALUES (700, 702, 'Greek_and_Coptic')")
    db.close
    Ucode::Database.new(path.to_s)
  end

  def write_config(hash)
    workdir.join("config.yml").write(YAML.dump(hash))
  end

  def write_font(name, content = "FONT-BYTES")
    workdir.join(name).binwrite(content)
  end

  def write_two_block_config_with_font(font_path)
    write_config(
      "unicode_version" => "17.0.0",
      "map" => {
        "Basic_Latin" => block_sources(font_path),
        "Greek_and_Coptic" => block_sources(font_path),
      },
    )
  end

  def block_sources(font_path)
    {
      "sources" => [{ "kind" => "path", "label" => "lentariso",
                      "path" => font_path.to_s, "priority" => 1 }],
    }
  end

  def counting_locator(available:)
    Class.new(StaticFontLocator) do
      attr_reader :call_count

      def initialize(...)
        super
        @call_count = 0
      end

      def locate(...)
        @call_count += 1
        super
      end
    end.new(available: available)
  end

  describe "PreBuildReport" do
    it "is ok? when config loads and no fonts are missing" do
      write_font("Lentariso.otf")
      write_config(
        "unicode_version" => "17.0.0",
        "map" => {
          "Basic_Latin" => {
            "sources" => [{ "kind" => "path", "label" => "lentariso",
                            "path" => workdir.join("Lentariso.otf").to_s,
                            "priority" => 1 }],
          },
        },
      )
      report = described_class.new(
        source_config_path: workdir.join("config.yml"),
        database: database, cmaps: cmaps,
      ).call

      expect(report).to be_a(Ucode::Glyphs::UniversalSet::PreBuildReport)
      expect(report.ok?).to be(true)
      expect(report.config_loaded).to be(true)
      expect(report.missing_fonts).to be_empty
      expect(report.unicode_version).to eq("17.0.0")
    end
  end

  describe "when the source config is missing" do
    it "raises UniversalSetPreBuildError with config_loaded=false" do
      expect do
        described_class.new(
          source_config_path: workdir.join("nonexistent.yml"),
          database: database, cmaps: cmaps,
        ).call
      end.to raise_error(Ucode::UniversalSetPreBuildError) do |err|
        expect(err.context[:config_loaded]).to be(false)
      end
    end
  end

  describe "when a path font is missing on disk" do
    it "raises UniversalSetPreBuildError listing the missing font" do
      write_config(
        "unicode_version" => "17.0.0",
        "map" => {
          "Basic_Latin" => {
            "sources" => [{ "kind" => "path", "label" => "lentariso",
                            "path" => workdir.join("missing.otf").to_s,
                            "priority" => 1 }],
          },
        },
      )
      expect do
        described_class.new(
          source_config_path: workdir.join("config.yml"),
          database: database, cmaps: cmaps,
        ).call
      end.to raise_error(Ucode::UniversalSetPreBuildError) do |err|
        missing = err.context[:missing_fonts]
        expect(missing.length).to eq(1)
        expect(missing.first[:kind]).to eq("path")
        expect(missing.first[:label]).to eq("lentariso")
      end
    end
  end

  describe "when a fontist formula cannot be resolved" do
    it "raises UniversalSetPreBuildError listing the missing formula" do
      locator = StaticFontLocator.new(available: ["noto-sans"]) # missing: lentariso

      write_config(
        "unicode_version" => "17.0.0",
        "map" => {
          "Basic_Latin" => {
            "sources" => [{ "kind" => "fontist", "label" => "lentariso",
                            "priority" => 1 }],
          },
        },
      )
      expect do
        described_class.new(
          source_config_path: workdir.join("config.yml"),
          database: database, cmaps: cmaps, font_locator: locator,
        ).call
      end.to raise_error(Ucode::UniversalSetPreBuildError) do |err|
        missing = err.context[:missing_fonts]
        expect(missing.length).to eq(1)
        expect(missing.first[:kind]).to eq("fontist")
        expect(missing.first[:label]).to eq("lentariso")
      end
    end
  end

  describe "when a fontist formula is resolvable" do
    it "passes with ok? true" do
      locator = StaticFontLocator.new(available: ["lentariso"])
      write_config(
        "unicode_version" => "17.0.0",
        "map" => {
          "Basic_Latin" => {
            "sources" => [{ "kind" => "fontist", "label" => "lentariso",
                            "priority" => 1 }],
          },
        },
      )
      report = described_class.new(
        source_config_path: workdir.join("config.yml"),
        database: database, cmaps: cmaps, font_locator: locator,
      ).call
      expect(report.ok?).to be(true)
      expect(report.missing_fonts).to be_empty
    end
  end

  describe "coverage gaps (TODO 29 walker)" do
    it "still produces ok? true when there are gaps (gaps do not abort)" do
      write_font("Lentariso.otf")
      write_config(
        "unicode_version" => "17.0.0",
        "map" => {
          # Basic_Latin spans 65..67 in our test DB; the cmaps cover
          # all three codepoints. Greek_and_Coptic (700..702) has
          # no source — that's not a gap, it's uncurated.
          "Basic_Latin" => {
            "sources" => [{ "kind" => "path", "label" => "lentariso",
                            "path" => workdir.join("Lentariso.otf").to_s,
                            "priority" => 1 }],
          },
        },
      )
      report = described_class.new(
        source_config_path: workdir.join("config.yml"),
        database: database, cmaps: cmaps,
      ).call

      expect(report.ok?).to be(true)
      expect(report.coverage_gaps).to be_a(Ucode::Glyphs::SourceConfig::GapReport)
      expect(report.coverage_gaps.total_gaps).to eq(0)
    end

    it "records gaps in the coverage_gaps report but does not abort" do
      write_font("Lentariso.otf")
      # Greek_and_Coptic (700..702) is configured but the cmap doesn't
      # cover those codepoints — that's a gap, not an abort.
      write_two_block_config_with_font(workdir.join("Lentariso.otf"))
      report = described_class.new(
        source_config_path: workdir.join("config.yml"),
        database: database, cmaps: cmaps,
      ).call

      expect(report.ok?).to be(true)
      expect(report.coverage_gaps.total_gaps).to eq(3)
      expect(report.coverage_gaps.codepoints_for("Greek_and_Coptic"))
        .to contain_exactly(700, 701, 702)
    end
  end

  describe "deduplicating sources referenced by multiple blocks" do
    it "only checks each unique font once" do
      write_font("Lentariso.otf")
      locator = counting_locator(available: ["lentariso"])

      write_config(
        "unicode_version" => "17.0.0",
        "default_sources" => [{ "kind" => "fontist", "label" => "lentariso",
                                "priority" => 1 }],
        "map" => {
          "Basic_Latin" => { "sources" => [] },
          "Greek_and_Coptic" => { "sources" => [] },
        },
      )
      described_class.new(
        source_config_path: workdir.join("config.yml"),
        database: database, cmaps: cmaps, font_locator: locator,
      ).call

      expect(locator.call_count).to eq(1)
    end
  end
end
