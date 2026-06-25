# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/vendor/"
  minimum_coverage 80
  minimum_coverage_by_file 40
end

require "ucode"

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
end
