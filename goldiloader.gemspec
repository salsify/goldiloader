# encoding: UTF-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'goldiloader/version'

Gem::Specification.new do |spec|
  spec.name          = 'goldiloader'
  spec.version       = Goldiloader::VERSION
  spec.authors       = ['Joel Turkel']
  spec.email         = ['jturkel@salsify.com']
  spec.description   = "Automatically eager loads Rails associations as associations are traversed"
  spec.summary       = "Automatic Rails association eager loading"
  spec.homepage      = 'https://github.com/salsify/goldiloader'
  spec.license       = 'MIT'

  spec.files         = `git ls-files lib Readme.md LICENSE.txt`.split($/)

  spec.required_ruby_version = '>= 2.1'

  spec.add_dependency 'activerecord', '>= 4.2', '< 5.2'
  spec.add_dependency 'activesupport', '>= 4.2', '< 5.2'

  spec.add_development_dependency 'appraisal'
  spec.add_development_dependency 'coveralls'
  spec.add_development_dependency 'database_cleaner', '>= 1.2'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 3'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'mime-types'

  if RUBY_PLATFORM == 'java'
    spec.add_development_dependency 'jdbc-sqlite3'
    spec.add_development_dependency 'activerecord-jdbcsqlite3-adapter'
  else
    spec.add_development_dependency 'sqlite3'
  end
end

