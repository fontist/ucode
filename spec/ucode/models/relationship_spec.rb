# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Relationship do
  describe "subclass discriminator defaults" do
    it "CrossReference defaults kind to 'see_also'" do
      expect(Ucode::Models::Relationship::CrossReference.new.kind).to eq("see_also")
    end

    it "SampleSequence defaults kind to 'sample_sequence'" do
      expect(Ucode::Models::Relationship::SampleSequence.new.kind).to eq("sample_sequence")
    end

    it "CompatEquiv defaults kind to 'compatibility_equivalent'" do
      expect(Ucode::Models::Relationship::CompatEquiv.new.kind).to eq("compatibility_equivalent")
    end

    it "InformalAlias defaults kind to 'alias'" do
      expect(Ucode::Models::Relationship::InformalAlias.new.kind).to eq("alias")
    end

    it "Footnote defaults kind to 'footnote'" do
      expect(Ucode::Models::Relationship::Footnote.new.kind).to eq("footnote")
    end

    it "VariationSequence defaults kind to 'variation_sequence'" do
      expect(Ucode::Models::Relationship::VariationSequence.new.kind).to eq("variation_sequence")
    end
  end

  describe "consumer-side polymorphism via CodePoint" do
    it "round-trips a CodePoint with mixed-type relationships" do
      cp = Ucode::Models::CodePoint.new(
        cp: 0x0041,
        id: "U+0041",
        relationships: [
          Ucode::Models::Relationship::CrossReference.new(
            target_ids: %w[U+0061], description: "see lowercase"
          ),
          Ucode::Models::Relationship::InformalAlias.new(description: "lowercase a"),
          Ucode::Models::Relationship::Footnote.new(
            description: "used in ASCII", category: "history"
          ),
        ]
      )
      restored = Ucode::Models::CodePoint.from_hash(Ucode::Models::CodePoint.to_hash(cp))

      expect(restored.relationships.size).to eq(3)
      expect(restored.relationships[0]).to be_an(Ucode::Models::Relationship::CrossReference)
      expect(restored.relationships[0].target_ids).to eq(%w[U+0061])
      expect(restored.relationships[1]).to be_an(Ucode::Models::Relationship::InformalAlias)
      expect(restored.relationships[1].description).to eq("lowercase a")
      expect(restored.relationships[2]).to be_an(Ucode::Models::Relationship::Footnote)
      expect(restored.relationships[2].category).to eq("history")
    end

    it "round-trips a CodePoint with an empty relationships collection" do
      cp = Ucode::Models::CodePoint.new(cp: 0x0041, id: "U+0041")
      restored = Ucode::Models::CodePoint.from_hash(Ucode::Models::CodePoint.to_hash(cp))
      expect(restored.relationships).to eq([])
    end
  end
end

RSpec.describe Ucode::Models::Relationship::CrossReference do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(target_ids: %w[U+0061], description: "latin small a")
    end
  end
end

RSpec.describe Ucode::Models::Relationship::SampleSequence do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        target_ids: %w[U+0061 U+0300],
        description: "grave accent",
        rendered_form: "à"
      )
    end
  end
end

RSpec.describe Ucode::Models::Relationship::CompatEquiv do
  it_behaves_like "a round-trippable model" do
    let(:instance) { described_class.new(target_ids: %w[U+0061]) }
  end
end

RSpec.describe Ucode::Models::Relationship::InformalAlias do
  it_behaves_like "a round-trippable model" do
    let(:instance) { described_class.new(description: "fake name") }
  end
end

RSpec.describe Ucode::Models::Relationship::Footnote do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(description: "history note", category: "history")
    end
  end
end

RSpec.describe Ucode::Models::Relationship::VariationSequence do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(target_ids: %w[U+FE00], contexts: %w[singleton])
    end
  end
end
