# frozen_string_literal: true

module Goldiloader
  # Gives models, and the models of their loaded associations, new auto include contexts as if they had been
  # loaded with includes: the models passed share one per class, and so do the loaded targets of each association.
  module AutoIncludeContextReset
    extend self

    def reset(models)
      visited_models = Set.new.compare_by_identity
      reflections = Hash.new { |cache, model_class| cache[model_class] = model_class.reflect_on_all_associations }
      disabled_scopes = {}.compare_by_identity
      groups = [models]

      until groups.empty?
        groups = groups.flat_map do |group|
          group = group.select { |model| model && !model.new_record? && visited_models.add?(model) }
          # Models of unrelated classes are never loaded together, a polymorphic belongs_to loads one class at a time
          group.group_by { |model| model.class.base_class }.values.flat_map do |class_group|
            Goldiloader::AutoIncludeContext.new.register_models(class_group)
            loaded_target_groups(class_group, reflections, disabled_scopes)
          end
        end
      end

      models
    end

    private

    # The loaded targets of each association share a context, as when preloaded, unless its scope uses
    # auto_include(false): each target then gets its own
    def loaded_target_groups(models, reflections, disabled_scopes)
      targets_by_reflection = {}.compare_by_identity
      single_groups = []

      models.each do |model|
        reflections[model.class].each do |reflection|
          next unless model.association_cached?(reflection.name)

          association = model.association(reflection.name)
          next unless association.loaded?

          # Don't use Array.wrap(), see AutoIncludeContext#register_models
          target = association.target
          targets = target.is_a?(Array) ? target : [target].compact
          next if targets.empty?

          if auto_include_disabled?(association, disabled_scopes)
            targets.each { |target_model| single_groups << [target_model] }
          else
            (targets_by_reflection[reflection] ||= []).concat(targets)
          end
        end
      end

      targets_by_reflection.values.concat(single_groups)
    end

    # Read from the scope once per class and call, as in AssociationReflectionPatch#eager_loadable?. A scope
    # taking the owner is never evaluated.
    def auto_include_disabled?(association, disabled_scopes)
      # Not the listed reflection, which for a HABTM keeps a scope Rails never calls as is
      reflection = association.reflection
      scope = reflection.scope
      return false if scope.nil? || scope.arity > 0

      klass = association.klass
      return false if klass.nil?

      by_class = disabled_scopes[reflection] ||= {}.compare_by_identity
      by_class.fetch(klass) do
        by_class[klass] = !reflection.eager_loadable?(klass) &&
                          !Goldiloader::ScopeInfo.new(reflection.scope_for(klass.unscoped)).auto_include?
      end
    end
  end
end
