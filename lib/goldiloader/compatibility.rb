# encoding: UTF-8

module Goldiloader
  module Compatibility
    ACTIVE_RECORD_VERSION = ::Gem::Version.new(::ActiveRecord::VERSION::STRING)
  end
end
