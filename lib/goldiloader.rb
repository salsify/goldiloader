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

    # Gives models that lost their auto include context, typically when read back from a cache, and the
    # models of their loaded associations the contexts a regular load would have given them. Models that
    # still have one, like those just loaded on a cache miss, keep it.
    def restore_auto_include(models)
      top_level_models = models.is_a?(ActiveRecord::Base) ? [models] : models.to_a.compact
      visited_models = Set.new.compare_by_identity
      # Like a query result, each group shares a context
      groups = top_level_models.group_by { |model| model.class.base_class }.values

      until groups.empty?
        groups = groups.flat_map do |group|
          group = group.select { |model| visited_models.add?(model) }
          lost_context = group.reject { |model| model.instance_variable_get(:@auto_include_context) }
          Goldiloader::AutoIncludeContext.register_models(lost_context) unless lost_context.empty?
          loaded_target_groups(group)
        end
      end

      models
    end

    private

    # Groups the loaded targets of models sharing a context the way a regular load would have loaded them:
    # one query per association that can be eager loaded (one per class for a polymorphic belongs_to),
    # otherwise one query per model.
    def loaded_target_groups(models)
      targets_by_reflection = {}.compare_by_identity
      lazy_groups = []

      models.each do |model|
        model.class.reflect_on_all_associations.each do |reflection|
          next unless model.association_cached?(reflection.name)

          association = model.association(reflection.name)
          next unless association.loaded? && association.klass

          # Don't use Array.wrap(), see AutoIncludeContext#register_models
          target = association.target
          targets = target.is_a?(Array) ? target : [target].compact
          next if targets.empty?

          if reflection.eager_loadable?(association.klass)
            (targets_by_reflection[reflection] ||= []).concat(targets)
          else
            lazy_groups.concat(targets.map { |target_model| [target_model] })
          end
        end
      end

      eager_groups = targets_by_reflection.flat_map do |reflection, targets|
        if reflection.polymorphic?
          targets.group_by { |target| target.class.base_class }.values
        else
          [targets]
        end
      end

      eager_groups + lazy_groups
    end
  end

  self.globally_enabled = true
end
