# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::EmbeddingType do
  it_behaves_like "a round-trippable model" do
    let(:instance) { described_class.new(value: "installable") }
  end

  describe ".decode" do
    it "returns nil for nil input" do
      expect(described_class.decode(nil)).to be_nil
    end

    it "returns 'installable' for 0" do
      expect(described_class.decode(0)).to eq("installable")
    end

    it "returns 'restricted_license' for the restricted bit" do
      expect(described_class.decode(0x0001)).to eq("restricted_license")
    end

    it "returns 'preview_print' for the preview bit" do
      expect(described_class.decode(0x0002)).to eq("preview_print")
    end

    it "returns 'editable' for the editable bit" do
      expect(described_class.decode(0x0004)).to eq("editable")
    end

    it "returns 'installable' for the installable bit alone" do
      expect(described_class.decode(0x0008)).to eq("installable")
    end

    it "returns 'installable_no_subsetting' for installable + no_subsetting" do
      expect(described_class.decode(0x0108)).to eq("installable_no_subsetting")
    end

    it "returns 'installable_bitmap_only' for installable + bitmap_only" do
      expect(described_class.decode(0x0208)).to eq("installable_bitmap_only")
    end

    it "returns 'installable_no_subsetting_bitmap_only' for all installable modifiers" do
      expect(described_class.decode(0x0308)).to eq("installable_no_subsetting_bitmap_only")
    end

    it "prioritizes restricted over installable" do
      expect(described_class.decode(0x0009)).to eq("restricted_license")
    end
  end

  describe ".from_fs_type" do
    it "builds an instance with the decoded value" do
      instance = described_class.from_fs_type(0x0004)
      expect(instance.value).to eq("editable")
    end
  end

  describe "#to_s" do
    it "delegates to value" do
      expect(described_class.new(value: "preview_print").to_s).to eq("preview_print")
    end
  end
end
