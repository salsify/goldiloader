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
      models_to_register = models.is_a?(ActiveRecord::Base) ? [models] : models.to_a.compact
      registered_models = Set.new.compare_by_identity

      until models_to_register.empty?
        models_to_register = models_to_register.select { |model| registered_models.add?(model) }
        models_to_register.group_by { |model| model.class.base_class }.each_value do |models_of_class|
          Goldiloader::AutoIncludeContext.register_models(models_of_class)
        end
        models_to_register = loaded_auto_include_targets(models_to_register)
      end

      models
    end

    private

    def loaded_auto_include_targets(models)
      models.group_by(&:class).flat_map do |model_class, models_of_class|
        model_class.reflect_on_all_associations.flat_map do |reflection|
          models_of_class.flat_map do |model|
            next [] unless model.association_cached?(reflection.name)

            association = model.association(reflection.name)
            next [] unless association.loaded? && association.klass && reflection.eager_loadable?(association.klass)

            # Don't use Array.wrap(), see AutoIncludeContext#register_models
            target = association.target
            target.is_a?(Array) ? target : [target].compact
          end
        end
      end
    end
  end

  self.globally_enabled = true
end
