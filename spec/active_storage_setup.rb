# frozen_string_literal: true

# Copy initialization from activestorage/lib/active_storage/engine.rb
# There's probably a cleaner way to do all of this...
require 'active_storage'
require 'active_storage/attached'
require 'active_storage/service/disk_service'

ActiveStorage.logger = ActiveRecord::Base.logger

ActiveStorage::Service::DiskService.class_eval do
  def url(key, **)
    "http://localhost/#{key}"
  end
end

# Stub ActiveStorage::AnalyzeJob to avoid a dependency on ActiveJob
module ActiveStorage
  class AnalyzeJob
    def self.perform_later(blob)
      blob.analyze
    end
  end
end

if Goldiloader::Compatibility.rails_5_2?
  ActiveRecord::Base.extend(ActiveStorage::Attached::Macros)
else
  require 'active_storage/reflection'

  ActiveRecord::Base.include(ActiveStorage::Attached::Model)
  ActiveRecord::Base.include(ActiveStorage::Reflection::ActiveRecordExtensions)
  ActiveRecord::Reflection.singleton_class.prepend(ActiveStorage::Reflection::ReflectionExtension)
end

# Add the ActiveStore engine files to the load path
active_storage_version_file = Gem.find_files('active_storage/version.rb').first
$LOAD_PATH.unshift(File.expand_path('../../../app/models', active_storage_version_file))

module Rails
  module Autoloaders
    def self.zeitwerk_enabled?
      false
    end
  end

  def self.autoloaders
    Autoloaders
  end
end

if Goldiloader::Compatibility.rails_6_1_or_greater?
  require 'active_storage/record'
  # TODO: Figure out how these circular requires should work
  module ActiveStorage
    class Blob < ActiveStorage::Record; end
  end
  require 'active_storage/blob/analyzable'
  require 'active_storage/blob/identifiable'
  require 'active_storage/blob/representable'
end

require 'active_storage/attachment'
require 'active_storage/blob'
# require 'active_storage/current'
require 'active_storage/filename'

ActiveStorage::Blob.service = ActiveStorage::Service::DiskService.new(root: Pathname('tmp/storage'))

if Goldiloader::Compatibility.rails_6_1_or_greater?
  ActiveStorage::Blob.service.name = 'temp_storage'
  ActiveStorage::Blob.services[ActiveStorage::Blob.service.name] = ActiveStorage::Blob.service
end
