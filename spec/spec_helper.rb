# frozen_string_literal: true

require 'simplecov'
require 'coveralls'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
  [SimpleCov::Formatter::HTMLFormatter, Coveralls::SimpleCov::Formatter]
)

SimpleCov.start do
  add_filter 'benchmark'
  add_filter 'gemfiles'
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

if Goldiloader::Compatibility.rails_5_2_or_greater?
  # Copy initialization from activestorage/lib/active_storage/engine.rb
  require 'active_storage'
  require 'active_storage/attached'
  require 'active_storage/service/disk_service'

  ActiveStorage.logger = ActiveRecord::Base.logger

  ActiveStorage::Service::DiskService.class_eval do
    def url(key, **)
      "http://localhost/#{key}"
    end
  end

  # Stub ActiveStorage::AnalyzeJob to avoid a dependency on ActiveJob
  module ActiveStorage
    class AnalyzeJob
      def self.perform_later(blob)
        blob.analyze
      end
    end
  end

  if Goldiloader::Compatibility.rails_5_2?
    ActiveRecord::Base.extend(ActiveStorage::Attached::Macros)
  else
    require 'active_storage/reflection'

    ActiveRecord::Base.include(ActiveStorage::Attached::Model)
    ActiveRecord::Base.include(ActiveStorage::Reflection::ActiveRecordExtensions)
    ActiveRecord::Reflection.singleton_class.prepend(ActiveStorage::Reflection::ReflectionExtension)
  end

  # Add the ActiveStore engine files to the load path
  active_storage_version_file = Gem.find_files('active_storage/version.rb').first
  $LOAD_PATH.unshift(File.expand_path('../../../app/models', active_storage_version_file))

  module Rails
    module Autoloaders
      def self.zeitwerk_enabled?
        false
      end
    end

    def self.autoloaders
      Autoloaders
    end
  end

  require 'active_storage/attachment'
  require 'active_storage/blob'
  # require 'active_storage/current'
  require 'active_storage/filename'

  ActiveStorage::Blob.service = ActiveStorage::Service::DiskService.new(root: Pathname('tmp/storage'))
  # ActiveStorage.verifier = ActiveSupport::MessageVerifier.new("Testing")
  # ActiveStorage::Current.host = 'localhost'
end

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

# Takes a hash from model class to the number of expected queries executed for that model e.g.
# expect {  }.to execute_queries(Post => 2, User => 1)
RSpec::Matchers.define(:execute_queries) do |expected_counts|
  match(notify_expectation_failures: true) do |actual|
    @actual_queries = []
    listener = lambda do |_name, _start, _finish, _message_id, values|
      @actual_queries << values[:sql]
    end

    ActiveSupport::Notifications.subscribed(listener, 'sql.active_record', &actual)

    expected_counts_by_table = expected_counts.transform_keys(&:table_name)

    table_extractor = /SELECT .* FROM "(.+)" WHERE/
    actual_counts_by_table = @actual_queries.group_by do |query|
      table_extractor.match(query)[1]
    end.transform_values(&:size)

    actual_counts_by_table == expected_counts_by_table
  end

  failure_message do |_actual|
    "expected #{expected_counts.transform_keys(&:name)} queries but ran:\n#{@actual_queries.join("\n")}"
  end

  supports_block_expectations
end

puts "Testing with ActiveRecord #{ActiveRecord::VERSION::STRING}"
