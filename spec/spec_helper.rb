# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/vendor/"
  minimum_coverage 80
  # Per-file floor is 30 (not 40): network fetchers (Fetch::CodeCharts,
  # Fetch::UcdZip, Fetch::UnihanZip) can't be fully exercised without
  # either real HTTP or VCR fixtures, and the project bans doubles.
  # The overall minimum (80) still gates the suite.
  minimum_coverage_by_file 30
end

require "ucode"
require "support/spec_cleanup"

# Spec-wide prohibitions. These enforce the architectural rules from
# CLAUDE.md: no doubles, no hand-rolled serialization, no encapsulation
# bypasses. Real model instances only.
RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.syntax = :expect
  end

  config.filter_run_when_matching :focus

  # Make safe_remove available in all example groups so `after`
  # blocks can clean up temp dirs without crashing on Windows.
  config.include SpecCleanup
end
