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
