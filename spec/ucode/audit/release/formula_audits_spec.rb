# frozen_string_literal: true

require "spec_helper"
require "support/emitter_spec_helpers"

RSpec.describe Ucode::Audit::Release::FormulaAudits, type: :emitter_spec do
  let(:summary) { build_library_summary(reports: [build_audit_report]) }

  describe "construction" do
    it "accepts a slug + summary pair" do
      fa = described_class.new(slug: "inter", summary: summary)
      expect(fa.slug).to eq("inter")
      expect(fa.summary).to eq(summary)
    end

    it "exposes face_reports from the summary" do
      fa = described_class.new(slug: "inter", summary: summary)
      expect(fa.face_reports.size).to eq(1)
      expect(fa.face_reports.first).to be_a(Ucode::Models::Audit::AuditReport)
    end

    it "exposes faces_total from the summary" do
      fa = described_class.new(slug: "inter", summary: summary)
      expect(fa.faces_total).to eq(summary.total_faces)
    end
  end

  describe "slug validation" do
    it "rejects an empty slug" do
      expect { described_class.new(slug: "", summary: summary) }
        .to raise_error(ArgumentError, /slug must not be empty/)
    end

    it "rejects a slug with path separators" do
      expect { described_class.new(slug: "inter/sub", summary: summary) }
        .to raise_error(ArgumentError, /path separators/)
    end

    it "rejects a slug that is not filesystem-safe" do
      expect { described_class.new(slug: "inter sub!", summary: summary) }
        .to raise_error(ArgumentError, /filesystem-safe/)
    end

    it "rejects a nil summary" do
      expect { described_class.new(slug: "inter", summary: nil) }
        .to raise_error(ArgumentError, /summary is required/)
    end

    it "accepts slug forms typical of fontist formulas" do
      %w[inter noto-sans dejaVu.sans source_code_pro].each do |slug|
        fa = described_class.new(slug: slug, summary: summary)
        expect(fa.slug).to eq(slug)
      end
    end
  end
end
