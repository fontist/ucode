# frozen_string_literal: true

require_relative "lib/ucode/version"

Gem::Specification.new do |spec|
  spec.name = "ucode"
  spec.version = Ucode::VERSION
  spec.authors = ["Ribose Inc."]
  spec.email = ["open.source@ribose.com"]

  spec.summary = "Unicode Character Database toolkit — lookup, dataset, glyphs, site"
  spec.description = <<~DESC
    ucode turns the Unicode Character Database (UCD) text files and the official
    Unicode Code Charts into a structured, browsable dataset. For every assigned
    codepoint it produces a JSON document with full UCD properties, the
    human-curated relationships from NamesList.txt, Unihan readings, and
    machine-computed references; an SVG of the official glyph vector-extracted
    from the Code Charts; and a Vitepress site for browsing Plane, Block,
    and Character.
  DESC

  spec.homepage = "https://github.com/fontist/ucode"
  spec.license = "BSD-2-Clause"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/fontist/ucode"
  spec.metadata["changelog_uri"] = "https://github.com/fontist/ucode/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      f == __FILE__ ||
        f.start_with?(".") ||
        f.start_with?("spec/") ||
        f.start_with?("benchmark/") ||
        f.start_with?("TODO.impl/") ||
        f.start_with?("docs/") ||
        f.start_with?("site/")
    end
  end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "base64"
  spec.add_dependency "bindata", "~> 2.5"
  spec.add_dependency "brotli", "~> 0.5"
  spec.add_dependency "fontisan", "~> 0.2"
  spec.add_dependency "fontist", "~> 3.0"
  spec.add_dependency "logger"
  spec.add_dependency "lutaml-model", "~> 0.8"
  spec.add_dependency "nokogiri", "~> 1.16"
  spec.add_dependency "rubyzip", "~> 2.3"
  spec.add_dependency "sqlite3", "~> 2.0"
  spec.add_dependency "thor", "~> 1.3"
end
