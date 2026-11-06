# frozen_string_literal: true

require 'active_support/all'
require 'goldiloader/compatibility'
require 'goldiloader/custom_preloads'
require 'goldiloader/auto_include_context'
require 'goldiloader/scope_info'
require 'goldiloader/association_options'
require 'goldiloader/association_loader'

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

    def register_models(models)
      register_loaded_together(models, Set.new.compare_by_identity)
      models
    end

    private

    def register_loaded_together(models, registered_models)
      models = models.select { |model| registered_models.add?(model) }

      models.group_by { |model| model.class.base_class }.each_value do |models_of_class|
        Goldiloader::AutoIncludeContext.new.register_models(models_of_class)
      end

      loaded_targets_by_reflection(models).each_value do |targets|
        register_loaded_together(targets, registered_models)
      end
    end

    def loaded_targets_by_reflection(models)
      targets_by_reflection = Hash.new { |hash, reflection| hash[reflection] = [] }

      models.each do |model|
        model.class.reflect_on_all_associations.each do |reflection|
          next unless model.association_cached?(reflection.name)

          association = model.association(reflection.name)
          next unless association.loaded?

          # Don't use Array.wrap(), see AutoIncludeContext#register_models
          target = association.target
          targets_by_reflection[reflection].concat(target.is_a?(Array) ? target : [target].compact)
        end
      end

      targets_by_reflection
    end
  end

  self.globally_enabled = true
end
