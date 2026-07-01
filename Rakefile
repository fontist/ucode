# frozen_string_literal: true

require "rubygems"
require "rake"
require "bundler/gem_tasks"

begin
  require "rspec/core/rake_task"
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
  # rspec is in the :development group; not available in the
  # release runner (`bundle install --without development`).
end

begin
  require "rubocop/rake_task"
  RuboCop::RakeTask.new
rescue LoadError
end

begin
  require "yard"
  YARD::Rake::YardocTask.new do |t|
    t.options = ["--output-dir", "docs/api"]
  end
rescue LoadError
end

task default: %i[spec rubocop]