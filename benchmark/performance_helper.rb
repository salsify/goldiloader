# frozen_string_literal: true

$LOAD_PATH.push(File.expand_path('../lib', __dir__))

require_relative 'lib/forking_benchmark'
require 'active_record'

ActiveRecord::Migration.verbose = false

def setup_database
  ActiveRecord::Base.establish_connection(
    adapter: 'sqlite3',
    database: ':memory:'
  )

  require_relative './db/schema'
end
