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
    # load would have given them. Other models, like those just loaded on a cache miss, are left as they are and
    # their associations aren't walked.
    # Takes a model, a loaded relation, or arrays and hashes holding them: the models directly in each array or
    # hash share a context, like a query result, and anything else is skipped.
    def restore_auto_include(models)
      groups = []
      collect_groups(models, groups, Set.new.compare_by_identity)
      visited_models = Set.new.compare_by_identity
      reflections = Hash.new { |cache, model_class| cache[model_class] = model_class.reflect_on_all_associations }
      scope_auto_includes = {}.compare_by_identity
      groups = groups.flat_map { |group| group.group_by { |model| model.class.base_class }.values }

      until groups.empty?
        # Larger groups first, so a model reached from several places joins the one most likely to batch it
        groups = groups.sort_by.with_index { |group, index| [-group.size, index] }.flat_map do |group|
          group = group.select { |model| visited_models.add?(model) }
          restored = group.select(&:auto_include_context_lost?)
          restored.each { |model| model.auto_include_context_lost = false }
          Goldiloader::AutoIncludeContext.register_models(restored.reject(&:new_record?))
          # Marshal and MessagePack flag every model they read back, so only restored models lead to others
          loaded_target_groups(restored, reflections, scope_auto_includes)
        end
      end

      models
    end

    private

    def collect_groups(value, groups, seen)
      case value
      when ActiveRecord::Base then groups << [value]
      when ActiveRecord::Relation then groups << value.records if value.loaded?
      when Array, Hash
        # Cached data can hold itself
        return unless seen.add?(value)

        group = []
        (value.is_a?(Hash) ? value.each_value : value).each do |element|
          element.is_a?(ActiveRecord::Base) ? group << element : collect_groups(element, groups, seen)
        end
        groups << group unless group.empty?
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
          next unless association.loaded?

          # Don't use Array.wrap(), see AutoIncludeContext#register_models
          target = association.target
          targets = target.is_a?(Array) ? target : [target].compact
          # Checked before klass, which raises for a polymorphic belongs_to with a nil target and a stale type
          next if targets.empty? || association.klass.nil?

          if reflection.eager_loadable?(association.klass)
            (targets_by_reflection[reflection] ||= []).concat(targets)
          elsif targets.one? || scope_auto_include?(association, scope_auto_includes)
            # A single target gets the same context either way, so the scope isn't evaluated for it
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
