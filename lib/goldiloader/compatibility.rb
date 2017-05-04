# encoding: UTF-8

module Goldiloader
  module Compatibility
    ACTIVE_RECORD_VERSION = ::Gem::Version.new(::ActiveRecord::VERSION::STRING)

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
