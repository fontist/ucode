# frozen_string_literal: true

require "spec_helper"
require "pathname"

RSpec.describe Ucode::Audit::Browser::Template do
  let(:template_dir) do
    Pathname.new(File.expand_path("../../../../lib/ucode/audit/browser/templates", __dir__))
  end

  it "ships all face template files" do
    %w[face.html.erb face.css face.js].each do |f|
      expect(template_dir.join(f).exist?).to be(true), "#{f} missing"
      expect(template_dir.join(f).size).to be > 0, "#{f} empty"
    end
  end

  it "ships all library template files" do
    %w[library.html.erb library.css library.js].each do |f|
      expect(template_dir.join(f).exist?).to be(true), "#{f} missing"
      expect(template_dir.join(f).size).to be > 0, "#{f} empty"
    end
  end

  it "renders the face template with inlined CSS and JS" do
    rendered = described_class.new(:face).render(
      overview_json: "{}",
      page_title: "Smoke",
      verbose: true,
      with_glyphs: false,
      universal_set: { "available" => false },
    )
    expect(rendered).to include("<!DOCTYPE html>")
    expect(rendered).to include("id=\"audit-overview\"")
    expect(rendered).to include("data-verbose=\"true\"")
    expect(rendered).to include("data-with-glyphs=\"false\"")
    expect(rendered).to include("data-universal-set-available=\"false\"")
  end

  it "ships all missing-glyph-page template files" do
    %w[missing_glyph_page.html.erb missing_glyph_page.css missing_glyph_page.js].each do |f|
      expect(template_dir.join(f).exist?).to be(true), "#{f} missing"
      expect(template_dir.join(f).size).to be > 0, "#{f} empty"
    end
  end

  it "renders the missing-glyph-page template with inlined CSS" do
    rendered = described_class.new(:missing_glyph_page).render(
      block_name: "Greek_and_Coptic",
      panels: [],
      visible_count: 0,
      total_count: 0,
      overflow_count: 0,
      universal_set_available: false,
    )
    expect(rendered).to include("<!DOCTYPE html>")
    expect(rendered).to include("<title>Greek_and_Coptic")
    expect(rendered).to include("No missing codepoints")
  end

  it "renders the library template with inlined CSS and JS" do
    rendered = described_class.new(:library).render(
      library_json: "{\"faces\":[]}",
      page_title: "Library",
    )
    expect(rendered).to include("<!DOCTYPE html>")
    expect(rendered).to include("id=\"library-overview\"")
    expect(rendered).to include("library-tagline")
  end
end
