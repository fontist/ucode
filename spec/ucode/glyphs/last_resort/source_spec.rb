# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Ucode::Glyphs::LastResort::Source do
  let(:fixture_root) do
    Pathname.new(__dir__).join("..", "..", "..", "fixtures", "last_resort")
  end

  it "resolves when given an explicit root pointing at a valid UFO" do
    source = described_class.new(root: fixture_root)
    expect(source.available?).to be true
    expect(source.cmap_path).to eq(fixture_root.join("cmap-f13.ttx"))
    expect(source.glyphs_dir).to eq(fixture_root.join("font.ufo", "glyphs"))
    expect(source.contents_path).to eq(fixture_root.join("font.ufo", "glyphs", "contents.plist"))
  end

  it "resolves via the UCODE_LAST_RESORT_FONT_ROOT env var when no explicit root" do
    env = { "UCODE_LAST_RESORT_FONT_ROOT" => fixture_root.to_s }
    source = described_class.new(env: env, gem_root: "/tmp/nonexistent-gem-root")
    expect(source.available?).to be true
  end

  it "prefers the explicit root over the env var" do
    env = { "UCODE_LAST_RESORT_FONT_ROOT" => "/tmp/does-not-exist" }
    source = described_class.new(root: fixture_root, env: env)
    expect(source.root).to eq(fixture_root)
  end

  it "falls back to the conventional sibling path when env is unset and no explicit root" do
    # The conventional path is <gem_root>/../external/unicode/last-resort-font
    # (two levels up from the gem root, then external/unicode/last-resort-font).
    # Build a real tmpdir tree matching the expected layout so the
    # Source's existence checks pass without depending on a dev-machine
    # checkout.
    Dir.mktmpdir do |grandparent|
      grandparent = Pathname.new(grandparent)
      gem_root = grandparent.join("workspace", "ucode")
      gem_root.mkpath
      # conventional_path: gem_root.parent.parent = grandparent
      ufo_root = grandparent.join("external", "unicode", "last-resort-font")
      ufo_root.join("font.ufo", "glyphs").mkpath
      ufo_root.join("cmap-f13.ttx").write("<x/>")
      ufo_root.join("font.ufo", "glyphs", "contents.plist").write("<x/>")

      source = described_class.new(gem_root: gem_root)
      expect(source.root).to eq(ufo_root)
    end
  end

  it "returns a missing error when the conventional path doesn't exist (no env, no explicit)" do
    # Use a gem_root that resolves to a non-existent path.
    fake_gem_root = Pathname.new(Dir.mktmpdir).join("fake-ucode")
    fake_gem_root.mkpath
    expect {
      described_class.new(env: {}, gem_root: fake_gem_root)
    }.to raise_error(Ucode::LastResortMissingError)
  end

  it "raises Ucode::LastResortMissingError when no candidate root is found" do
    expect {
      described_class.new(
        env: {},
        gem_root: "/tmp/nonexistent-ucode-root",
      )
    }.to raise_error(Ucode::LastResortMissingError, /Last Resort Font UFO source not found/)
  end

  it "raises when the resolved root is missing font.ufo/glyphs" do
    Dir.mktmpdir do |tmp|
      Pathname.new(tmp).join("cmap-f13.ttx").write("<x/>")
      expect {
        described_class.new(root: tmp)
      }.to raise_error(Ucode::LastResortMissingError)
    end
  end

  describe "#glif_path" do
    it "joins the glyphs dir with the basename" do
      source = described_class.new(root: fixture_root)
      expect(source.glif_path("lastresortlatin.glif"))
        .to eq(fixture_root.join("font.ufo", "glyphs", "lastresortlatin.glif"))
    end
  end
end
