require "bundler/gem_tasks"
Bundler::GemHelper.install_tasks

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new('spec')

# require 'yardstick/rake/verify'
# Yardstick::Rake::Verify.new do |verify|
#   verify.threshold = 100
# end

# require 'yardstick/rake/measurement'
# Yardstick::Rake::Measurement.new(:yardstick_measure) do |measurement|
#   measurement.output = 'measurement/report.txt'
# end

task :default => :spec
