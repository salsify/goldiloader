# encoding: UTF-8

module Goldiloader
  module Compatibility

    ACTIVE_RECORD_VERSION = ::Gem::Version.new(::ActiveRecord::VERSION::STRING)
    RAILS_3 = ACTIVE_RECORD_VERSION < ::Gem::Version.new('4')
    MASS_ASSIGNMENT_SECURITY = RAILS_3 || defined?(::ActiveRecord::MassAssignmentSecurity)
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

    # Copied from Rails since it is deprecated in Rails 5.0. Switch to using
    # Module#prepend when we drop Ruby 1.9 support.
    def self.alias_method_chain(klass, target, feature)
      # Strip out punctuation on predicates, bang or writer methods since
      # e.g. target?_without_feature is not a valid method name.
      aliased_target, punctuation = target.to_s.sub(/([?!=])$/, ''), $1
      yield(aliased_target, punctuation) if block_given?

      with_method = "#{aliased_target}_with_#{feature}#{punctuation}"
      without_method = "#{aliased_target}_without_#{feature}#{punctuation}"

      klass.send(:alias_method, without_method, target)
      klass.send(:alias_method, target, with_method)

      case
      when klass.public_method_defined?(without_method)
        klass.send(:public, target)
      when klass.protected_method_defined?(without_method)
        klass.send(:protected, target)
      when klass.private_method_defined?(without_method)
        klass.send(:private, target)
      end
    end
  end
end
