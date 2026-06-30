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

# Default to the published fontisan from rubygems. To develop against a
# local sibling checkout, set FONTISAN_PATH before running bundle.
#   FONTISAN_PATH=../fontisan bundle install
gem "fontisan", path: ENV["FONTISAN_PATH"] if ENV["FONTISAN_PATH"]
# Pin fontisan to 0.2.22 — 0.2.23+ removed
# `Fontisan::Commands::AuditCommand` and 0.4.x removed the Audit
# subsystem entirely. See ucode.gemspec for the rationale.
gem "fontisan", "= 0.2.22" unless ENV["FONTISAN_PATH"]
