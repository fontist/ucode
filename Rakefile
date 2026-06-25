# frozen_string_literal: true

require "rubygems"
require "rake"
require "bundler/gem_tasks"

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"
RuboCop::RakeTask.new

require "yard"
YARD::Rake::YardocTask.new do |t|
  t.options = ["--output-dir", "docs/api"]
end

task default: %i[spec rubocop]
