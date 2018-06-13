# encoding: UTF-8

module Goldiloader
  module Compatibility
    ACTIVE_RECORD_VERSION = ::Gem::Version.new(::ActiveRecord::VERSION::STRING)
    PRE_RAILS_5_2 = ACTIVE_RECORD_VERSION < ::Gem::Version.new('5.2.0')
    POST_RAILS_5_1_4 = ACTIVE_RECORD_VERSION > ::Gem::Version.new('5.1.5')
    PRE_RAILS_5_1_5 = ACTIVE_RECORD_VERSION < ::Gem::Version.new('5.1.5')
    FROM_EAGER_LOADABLE = ACTIVE_RECORD_VERSION >= ::Gem::Version.new('5.1.5') ||
      (ACTIVE_RECORD_VERSION >= ::Gem::Version.new('5.0.7') && ACTIVE_RECORD_VERSION < ::Gem::Version.new('5.1.0'))
    GROUP_EAGER_LOADABLE = FROM_EAGER_LOADABLE

    def self.rails_4?
      ::ActiveRecord::VERSION::MAJOR == 4
    end

    def self.rails_5_0?
      ::ActiveRecord::VERSION::MAJOR == 5 && ::ActiveRecord::VERSION::MINOR == 0
    end

    # See https://github.com/rails/rails/pull/32375
    def self.destroyed_model_associations_eager_loadable?
      PRE_RAILS_5_2
    end

    def self.from_eager_loadable?
      FROM_EAGER_LOADABLE
    end

    def self.group_eager_loadable?
      GROUP_EAGER_LOADABLE
    end
  end
end
