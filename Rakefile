require 'bundler/setup'
Bundler::GemHelper.install_tasks

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |task|
  task.verbose = false
end

task default: :spec
