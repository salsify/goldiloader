# frozen_string_literal: true

module Goldiloader
  module Compatibility
    ACTIVE_RECORD_VERSION = ::Gem::Version.new(::ActiveRecord::VERSION::STRING).release
    PRE_RAILS_6_2 = ACTIVE_RECORD_VERSION < ::Gem::Version.new('6.2.0')
    RAILS_5_2_0 = ACTIVE_RECORD_VERSION == ::Gem::Version.new('5.2.0')
    FROM_EAGER_LOADABLE = ACTIVE_RECORD_VERSION >= ::Gem::Version.new('5.1.5') ||
      (ACTIVE_RECORD_VERSION >= ::Gem::Version.new('5.0.7') && ACTIVE_RECORD_VERSION < ::Gem::Version.new('5.1.0'))
    GROUP_EAGER_LOADABLE = FROM_EAGER_LOADABLE

    def self.rails_4?
      ::ActiveRecord::VERSION::MAJOR == 4
    end

    def self.pre_rails_6_2?
      PRE_RAILS_6_2
    end

    # See https://github.com/rails/rails/pull/32375
    def self.destroyed_model_associations_eager_loadable?
      !RAILS_5_2_0
    end

    def self.from_eager_loadable?
      FROM_EAGER_LOADABLE
    end

    def self.group_eager_loadable?
      GROUP_EAGER_LOADABLE
    end
  end
end
