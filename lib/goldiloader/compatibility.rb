# frozen_string_literal: true

module Goldiloader
  module Compatibility
    ACTIVE_RECORD_VERSION = ::Gem::Version.new(::ActiveRecord::VERSION::STRING).release
    PRE_RAILS_6_2 = ACTIVE_RECORD_VERSION < ::Gem::Version.new('6.2.0')
    RAILS_5_2_0 = ACTIVE_RECORD_VERSION == ::Gem::Version.new('5.2.0')

    def self.pre_rails_6_2?
      PRE_RAILS_6_2
    end

    def self.rails_5_2?
      ::ActiveRecord::VERSION::MAJOR == 5 && ::ActiveRecord::VERSION::MINOR == 2
    end

    def self.rails_6_1?
      ::ActiveRecord::VERSION::MAJOR == 6 && ::ActiveRecord::VERSION::MINOR == 1
    end

    def self.rails_5_2_or_greater?
      ::ActiveRecord::VERSION::MAJOR >= 6 || rails_5_2?
    end

    def self.rails_6_1_or_greater?
      ::ActiveRecord::VERSION::MAJOR > 6 || rails_6_1?
    end

    # See https://github.com/rails/rails/pull/32375
    def self.destroyed_model_associations_eager_loadable?
      !RAILS_5_2_0
    end
  end
end
