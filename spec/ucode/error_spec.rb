# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Error do
  it "is a StandardError" do
    expect(described_class.new).to be_a(StandardError)
  end

  it "carries structured context" do
    error = described_class.new("boom", context: { codepoint: "U+0041", file: "UnicodeData.txt" })
    expect(error.context).to eq(codepoint: "U+0041", file: "UnicodeData.txt")
    expect(error.message).to include("boom")
    expect(error.message).to include("codepoint=")
    expect(error.message).to include("U+0041")
  end

  describe "hierarchy" do
    [
      [Ucode::FetchError, Ucode::Error],
      [Ucode::NetworkError, Ucode::FetchError],
      [Ucode::ChecksumError, Ucode::FetchError],
      [Ucode::ParseError, Ucode::Error],
      [Ucode::MalformedLineError, Ucode::ParseError],
      [Ucode::UnknownPropertyError, Ucode::ParseError],
      [Ucode::LookupError, Ucode::Error],
      [Ucode::DatabaseMissingError, Ucode::LookupError],
      [Ucode::DatabaseSchemaError, Ucode::LookupError],
      [Ucode::UnknownVersionError, Ucode::LookupError],
      [Ucode::GlyphError, Ucode::Error],
      [Ucode::LastResortMissingError, Ucode::GlyphError],
      [Ucode::EmbeddedFontsMissingError, Ucode::GlyphError],
    ].each do |leaf, parent|
      it "#{leaf} is a #{parent}" do
        expect(leaf.new).to be_a(parent)
      end
    end
  end
end
