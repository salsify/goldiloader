# frozen_string_literal: true

$LOAD_PATH.push(File.expand_path('../lib', __dir__))

require_relative 'lib/forking_benchmark'
require 'active_record'

ActiveRecord::Migration.verbose = false

if defined?(RubyVM::YJIT)
  RubyVM::YJIT.enable
else
  warn('Running benchmarks without YJIT since this Ruby was built without it.')
end

def setup_database
  ActiveRecord::Base.establish_connection(
    adapter: 'sqlite3',
    database: ':memory:'
  )

  require_relative './db/schema'
end
