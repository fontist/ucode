# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :development do
  gem "rake"
  gem "rspec"
  gem "rubocop"
  gem "rubocop-performance"
  gem "rubocop-rake"
  gem "rubocop-rspec"
  gem "simplecov"
  gem "yard"
end

# Local sibling checkout for in-development fontisan (glyph extraction).
gem "fontisan", "~> 0.2", path: "../fontisan" if Dir.exist?("../fontisan")
