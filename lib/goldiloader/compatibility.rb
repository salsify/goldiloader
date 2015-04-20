# encoding: UTF-8

module Goldiloader
  module Compatibility

    ACTIVE_RECORD_VERSION = ::Gem::Version.new(::ActiveRecord::VERSION::STRING)
    MASS_ASSIGNMENT_SECURITY = ACTIVE_RECORD_VERSION < ::Gem::Version.new('4') || defined?(::ActiveRecord::MassAssignmentSecurity)
    ASSOCIATION_FINDER_SQL = ACTIVE_RECORD_VERSION < ::Gem::Version.new('4.1')
    UNSCOPE_QUERY_METHOD = ACTIVE_RECORD_VERSION >= ::Gem::Version.new('4.1')
    JOINS_EAGER_LOADABLE = ACTIVE_RECORD_VERSION >= ::Gem::Version.new('4.2')
    UNSCOPED_EAGER_LOADABLE = ACTIVE_RECORD_VERSION >= ::Gem::Version.new('4.1.9')

    def self.mass_assignment_security_enabled?
      MASS_ASSIGNMENT_SECURITY
    end

    def self.association_finder_sql_enabled?
      ASSOCIATION_FINDER_SQL
    end

    def self.unscope_query_method_enabled?
      UNSCOPE_QUERY_METHOD
    end

    def self.joins_eager_loadable?
      # Associations with joins were not eager loadable prior to Rails 4.2 due to
      # https://github.com/rails/rails/pull/17678
      JOINS_EAGER_LOADABLE
    end

    def self.unscoped_eager_loadable?
      # Unscoped associations weren't properly eager loaded until after Rails 4.1.9.
      # See https://github.com/rails/rails/issues/11036.
      UNSCOPED_EAGER_LOADABLE
    end
  end
end
