# frozen_string_literal: true

module Goldiloader
  module Compatibility
    ACTIVE_RECORD_VERSION = ::Gem::Version.new(::ActiveRecord::VERSION::STRING).release
    PRE_RAILS_6_2 = ACTIVE_RECORD_VERSION < ::Gem::Version.new('6.2.0')
    RAILS_5_2_0 = ACTIVE_RECORD_VERSION == ::Gem::Version.new('5.2.0')

    def self.pre_rails_6_2?
      PRE_RAILS_6_2
    end

    # See https://github.com/rails/rails/pull/32375
    def self.destroyed_model_associations_eager_loadable?
      !RAILS_5_2_0
    end
  end
end
