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

    # Gives models read back from a cache, and the models of their loaded associations, the contexts a regular
    # load would have given them. Other models, like those just loaded on a cache miss, are left as they are.
    # Takes a model, a relation, or arrays and hashes holding models; anything else is skipped.
    def restore_auto_include(models)
      top_level_models = []
      collect_models(models, top_level_models)
      visited_models = Set.new.compare_by_identity
      reflections = Hash.new { |cache, model_class| cache[model_class] = model_class.reflect_on_all_associations }
      scope_auto_includes = {}.compare_by_identity
      # Like a query result, each group shares a context
      groups = top_level_models.group_by { |model| model.class.base_class }.values

      until groups.empty?
        groups = groups.flat_map do |group|
          group = group.select { |model| visited_models.add?(model) }
          restored = group.select(&:auto_include_context_lost?)
          Goldiloader::AutoIncludeContext.register_models(restored)
          restored.each { |model| model.auto_include_context_lost = false }
          loaded_target_groups(group, reflections, scope_auto_includes)
        end
      end

      models
    end

    private

    def collect_models(value, models)
      case value
      when ActiveRecord::Base then models << value
      when ActiveRecord::Relation then models.concat(value.to_a)
      when Array then value.each { |element| collect_models(element, models) }
      when Hash then value.each_value { |element| collect_models(element, models) }
      end
    end

    # Groups the loaded targets of models sharing a context the way a regular load would have loaded them:
    # one query per association that can be eager loaded and per class, otherwise one query per model, whose
    # results only share a context when the association's scope auto includes.
    def loaded_target_groups(models, reflections, scope_auto_includes)
      targets_by_reflection = {}.compare_by_identity
      lazy_groups = []

      models.each do |model|
        reflections[model.class].each do |reflection|
          next unless model.association_cached?(reflection.name)

          association = model.association(reflection.name)
          next unless association.loaded? && association.klass

          # Don't use Array.wrap(), see AutoIncludeContext#register_models
          target = association.target
          targets = target.is_a?(Array) ? target : [target].compact
          next if targets.empty?

          if reflection.eager_loadable?(association.klass)
            (targets_by_reflection[reflection] ||= []).concat(targets)
          elsif scope_auto_include?(association, scope_auto_includes)
            lazy_groups << targets
          else
            targets.each { |target_model| lazy_groups << [target_model] }
          end
        end
      end

      targets_by_reflection.each_value.flat_map do |targets|
        targets.group_by { |target| target.class.base_class }.values
      end.concat(lazy_groups)
    end

    # Whether a regular load of the association registers its targets, i.e. its scope doesn't use
    # auto_include(false). Scopes taking the owner are evaluated per model, the others once per call.
    def scope_auto_include?(association, scope_auto_includes)
      scope = association.reflection.scope
      return true if scope.nil?
      return association.scope.auto_include_value if scope.arity > 0

      by_class = scope_auto_includes[association.reflection] ||= {}.compare_by_identity
      by_class.fetch(association.klass) do
        by_class[association.klass] = association.scope.auto_include_value
      end
    end
  end

  self.globally_enabled = true
end
