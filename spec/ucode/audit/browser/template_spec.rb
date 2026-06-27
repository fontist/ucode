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
    )
    expect(rendered).to include("<!DOCTYPE html>")
    expect(rendered).to include("id=\"audit-overview\"")
    expect(rendered).to include("data-verbose=\"true\"")
    expect(rendered).to include("data-with-glyphs=\"false\"")
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
