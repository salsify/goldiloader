# encoding: UTF-8

module Goldiloader
  module Compatibility

    MASS_ASSIGNMENT_SECURITY = ::ActiveRecord::VERSION::MAJOR < 4 || defined?(::ActiveRecord::MassAssignmentSecurity)
    ASSOCIATION_FINDER_SQL = ::Gem::Version.new(::ActiveRecord::VERSION::STRING) < ::Gem::Version.new('4.1')
    UNSCOPE_QUERY_METHOD = ::Gem::Version.new(::ActiveRecord::VERSION::STRING) >= ::Gem::Version.new('4.1')

    def self.mass_assignment_security_enabled?
      MASS_ASSIGNMENT_SECURITY
    end

    def self.association_finder_sql_enabled?
      ASSOCIATION_FINDER_SQL
    end

    def self.unscope_query_method_enabled?
      UNSCOPE_QUERY_METHOD
    end
  end
end
