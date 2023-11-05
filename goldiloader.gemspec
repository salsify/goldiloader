# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'goldiloader/version'

Gem::Specification.new do |spec|
  spec.name          = 'goldiloader'
  spec.version       = Goldiloader::VERSION
  spec.authors       = ['Joel Turkel']
  spec.email         = ['jturkel@salsify.com']
  spec.description   = 'Automatically eager loads Rails associations as associations are traversed'
  spec.summary       = 'Automatic Rails association eager loading'
  spec.homepage      = 'https://github.com/salsify/goldiloader'
  spec.metadata      = {
    'homepage_uri' => 'https://github.com/salsify/goldiloader',
    'changelog_uri' => 'https://github.com/salsify/goldiloader/blob/master/CHANGELOG.md',
    'source_code_uri' => 'https://github.com/salsify/goldiloader/',
    'bug_tracker_uri' => 'https://github.com/salsify/goldiloader/issues'
  }
  spec.license = 'MIT'

  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.org'
    spec.metadata['rubygems_mfa_required'] = 'true'
  else
    raise 'RubyGems 2.0 or newer is required to set allowed_push_host.'
  end

  spec.files = `git ls-files lib Readme.md LICENSE.txt`.split($INPUT_RECORD_SEPARATOR)

  spec.required_ruby_version = '>= 2.6'

  spec.add_dependency 'activerecord', '>= 5.2', '< 7.2'
  spec.add_dependency 'activesupport', '>= 5.2', '< 7.2'

  spec.add_development_dependency 'appraisal'
  spec.add_development_dependency 'benchmark-ips'
  spec.add_development_dependency 'combustion', '~> 1.3'
  spec.add_development_dependency 'coveralls_reborn', '>= 0.18.0'
  spec.add_development_dependency 'rails', '>= 5.2', '< 7.2'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 3'
  spec.add_development_dependency 'rspec_junit_formatter'
  spec.add_development_dependency 'rspec-rails'
  spec.add_development_dependency 'salsify_rubocop', '~> 1.0.1'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'sqlite3'
end
