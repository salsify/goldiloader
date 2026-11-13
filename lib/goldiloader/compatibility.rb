# frozen_string_literal: true

module Goldiloader
  module Compatibility
    # Memoized since it's checked on every through association load, once Active Record is loaded
    def self.pre_rails_8_2?
      return @pre_rails_8_2 if defined?(@pre_rails_8_2)

      @pre_rails_8_2 = ::ActiveRecord.gem_version < ::Gem::Version.new('8.2.0.alpha')
    end
  end
end
