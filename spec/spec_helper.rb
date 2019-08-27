# frozen_string_literal: true

require 'simplecov'
require 'coveralls'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
  [SimpleCov::Formatter::HTMLFormatter, Coveralls::SimpleCov::Formatter]
)

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

# TODO: If rails 5.2
require 'active_storage'
require "active_storage/attached"
ActiveRecord::Base.extend(ActiveStorage::Attached::Macros)
ActiveStorage::Blob.service = ActiveStorage::Service::DiskService.new(root: Pathname("tmp/storage"))
ActiveStorage.logger = ActiveSupport::Logger.new(nil)
ActiveStorage.verifier = ActiveSupport::MessageVerifier.new("Testing")

# TODO: If Rails 6
# ActiveRecord.include(ActiveStorage::Reflection::ActiveRecordExtensions)
# ActiveRecord::Reflection.singleton_class.prepend(ActiveStorage::Reflection::ReflectionExtension)

db_adapter = ENV.fetch('ADAPTER', 'sqlite3')
db_config = YAML.safe_load(File.read('spec/db/database.yml'))
ActiveRecord::Base.establish_connection(db_config[db_adapter])
require 'db/schema'



RSpec.configure do |config|
  config.order = 'random'

  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before do
    DatabaseCleaner.strategy = :transaction
  end

  config.before do
    DatabaseCleaner.start
  end

  config.after do
    DatabaseCleaner.clean
  end
end

puts "Testing with ActiveRecord #{ActiveRecord::VERSION::STRING}"
