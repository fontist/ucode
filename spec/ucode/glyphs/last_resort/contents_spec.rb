# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Glyphs::LastResort::Contents do
  let(:contents_path) do
    Pathname.new(__dir__).join("..", "..", "..", "fixtures", "last_resort", "font.ufo", "glyphs", "contents.plist")
  end

  describe ".parse" do
    it "returns a frozen Hash mapping glyph names to basenames" do
      index = described_class.parse(contents_path)
      expect(index).to be_frozen
      expect(index["lastresortlatin"]).to eq("lastresortlatin.glif")
      expect(index["lastresortgreek"]).to eq("lastresortgreek.glif")
      expect(index[".notdef"]).to eq("_notdef.glif")
    end
  end

  describe "instance API" do
    subject(:contents) { described_class.new(contents_path) }

    it "memoizes the parsed hash" do
      first = contents.to_h
      second = contents.to_h
      expect(second).to be(first)
    end

    it "looks up by glyph name" do
      expect(contents["lastresortgreek"]).to eq("lastresortgreek.glif")
    end

    it "returns nil for unknown glyph names" do
      expect(contents["doesnotexist"]).to be_nil
    end

    it "key? returns true for known names" do
      expect(contents.key?(".notdef")).to be true
      expect(contents.key?("missing")).to be false
    end
  end
end
