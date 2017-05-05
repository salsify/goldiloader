# encoding: UTF-8

module Goldiloader
  module Compatibility
    ACTIVE_RECORD_VERSION = ::Gem::Version.new(::ActiveRecord::VERSION::STRING)

    def self.rails_4?
      ::ActiveRecord::VERSION::MAJOR == 4
    end

    def self.rails_5_0?
      ::ActiveRecord::VERSION::MAJOR == 5 && ::ActiveRecord::VERSION::MINOR == 0
    end
  end
end
