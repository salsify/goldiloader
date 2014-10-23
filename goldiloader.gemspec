# encoding: UTF-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'goldiloader/version'

Gem::Specification.new do |spec|
  spec.name          = 'goldiloader'
  spec.version       = Goldiloader::VERSION
  spec.authors       = ['Joel Turkel']
  spec.email         = ['jturkel@salsify.com']
  spec.description   = %q{Automatically eager loads Rails associations as associations are traversed}
  spec.summary       = %q{Automatic Rails association eager loading}
  spec.homepage      = 'https://github.com/salsify/goldiloader'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.test_files    = Dir.glob('spec/**/*')
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', ENV.fetch('RAILS_VERSION', ['>= 3.2', '< 4.3'])
  spec.add_dependency 'activesupport', ENV.fetch('RAILS_VERSION', ['>= 3.2', '< 4.3'])

  spec.add_development_dependency 'coveralls'
  spec.add_development_dependency 'database_cleaner', '>= 1.2'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 2'
  spec.add_development_dependency 'simplecov', '~> 0.7.1'

  if RUBY_PLATFORM == 'java'
    spec.add_development_dependency 'jdbc-sqlite3'
    spec.add_development_dependency 'activerecord-jdbcsqlite3-adapter'
  else
    spec.add_development_dependency 'sqlite3'
  end

end

