# frozen_string_literal: true

require "spec_helper"
require "fontisan"
require "pathname"

RSpec.describe Ucode::Audit::Extractors::Licensing do
  let(:ttf_path) do
    Pathname.new(File.expand_path("../../../fixtures/fonts/NotoSansAdlam-Regular.ttf",
                                  __dir__))
  end
  let(:ttf_font) { Fontisan::FontLoader.load(ttf_path.to_s) }

  let(:context) do
    Ucode::Audit::Context.new(
      font: ttf_font,
      font_path: ttf_path,
      font_index: 0,
      num_fonts_in_source: 1,
      options: {},
    )
  end

  let(:fields) { described_class.new.extract(context) }

  it "returns a single :licensing field" do
    expect(fields.keys).to contain_exactly(:licensing)
  end

  it "returns a Ucode::Models::Audit::Licensing instance" do
    expect(fields[:licensing]).to be_a(Ucode::Models::Audit::Licensing)
  end

  it "populates copyright from nameID 0" do
    expect(fields[:licensing].copyright).not_to be_nil
  end

  it "populates vendor_id as a 4-char-max string" do
    vid = fields[:licensing].vendor_id
    expect(vid).to be_a(String)
    expect(vid.length).to be <= 4
  end

  it "populates embedding_type as a decoded canonical string" do
    et = fields[:licensing].embedding_type
    canonical = %w[restricted_license preview_print editable installable
                   installable_no_subsetting installable_bitmap_only
                   installable_no_subsetting_bitmap_only unknown]
    expect(et.nil? || canonical.include?(et)).to be(true)
  end

  it "populates fs_selection_flags as an array" do
    expect(fields[:licensing].fs_selection_flags).to be_an(Array).or(be_nil)
  end
end
