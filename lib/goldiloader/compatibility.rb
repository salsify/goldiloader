# encoding: UTF-8

module Goldiloader
  module Compatibility

    def self.mass_assignment_security_enabled?
      @mass_assignment_security_enabled ||= (::ActiveRecord::VERSION::MAJOR < 4 || defined?(::ActiveRecord::MassAssignmentSecurity))
    end

    def self.association_finder_sql_enabled?
      @association_finder_sql ||= (::Gem::Version.new(::ActiveRecord::VERSION::STRING) < ::Gem::Version.new('4.1'))
    end

    def self.unscope_query_method_enabled?
      @unscope_query_method ||= ::Gem::Version.new(::ActiveRecord::VERSION::STRING) >= ::Gem::Version.new('4.1')
    end
  end
end
