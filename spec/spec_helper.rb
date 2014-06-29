# encoding: UTF-8

require 'simplecov'
require 'coveralls'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]
SimpleCov.start do
 add_filter 'spec'
end

require 'logger'
require 'database_cleaner'
require 'goldiloader'
require 'yaml'

FileUtils.makedirs('log')

ActiveRecord::Base.logger = Logger.new('log/test.log')
ActiveRecord::Base.logger.level = Logger::DEBUG
ActiveRecord::Migration.verbose = false

db_adapter = ENV.fetch('ADAPTER', 'sqlite3')
config = YAML.load(File.read('spec/db/database.yml'))
ActiveRecord::Base.establish_connection(config[db_adapter])
require 'db/schema'

RSpec.configure do |config|
  config.order = 'random'

  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end

puts "Testing with ActiveRecord #{ActiveRecord::VERSION::STRING}"
