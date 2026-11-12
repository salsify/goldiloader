# frozen_string_literal: true

require 'active_support/all'
require 'goldiloader/compatibility'
require 'goldiloader/custom_preloads'
require 'goldiloader/auto_include_context'
require 'goldiloader/scope_info'
require 'goldiloader/association_options'
require 'goldiloader/association_loader'
require 'goldiloader/auto_include_context_reset'
require 'goldiloader/cache'

ActiveSupport.on_load(:active_record) do
  # Defer referencing ActiveRecord class until it's loaded
  # See https://github.com/rails/rails/issues/48704
  require 'goldiloader/active_record_patches'
end

module Goldiloader
  class << self

    # Sets the process-wide enabled status
    attr_accessor :globally_enabled

    def enabled?
      Thread.current.fetch(:goldiloader_enabled, globally_enabled)
    end

    def enabled=(val)
      Thread.current[:goldiloader_enabled] = val
    end

    def enabled
      old_enabled = Thread.current[:goldiloader_enabled]
      self.enabled = true
      yield
    ensure
      self.enabled = old_enabled
    end

    def disabled
      old_enabled = Thread.current[:goldiloader_enabled]
      self.enabled = false
      yield
    ensure
      self.enabled = old_enabled
    end

    # Gives an array of models, and the models of their loaded associations, new auto include contexts as if they
    # had been loaded with includes. Meant for models read back from a cache, which lose theirs, and not for models
    # that were just loaded: see Goldiloader::Cache.fetch.
    def reset_auto_include_context(models)
      Goldiloader::AutoIncludeContextReset.reset(models)
    end
  end

  self.globally_enabled = true
end
