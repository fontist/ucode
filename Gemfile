# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# Rake must be in the default group (not :development) because the
# GHA release workflow runs `bundle exec rake release` to publish the
# gem. The release runner installs with `--without development`, so
# gems in the :development group are excluded.
gem "rake"

group :development do
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
# fontist itself constrains fontisan to ~> 0.2, so we must stay in the
# 0.2.x series. 0.2.23+ removed AuditCommand — CoverageAuditor guards
# its absence with const_defined?.
gem "fontisan", path: ENV["FONTISAN_PATH"] if ENV["FONTISAN_PATH"]
gem "fontisan", ">= 0.2.22", "< 0.3" unless ENV["FONTISAN_PATH"]
