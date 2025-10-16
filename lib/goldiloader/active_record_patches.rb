# frozen_string_literal: true

module Goldiloader
  module BasePatch
    extend ActiveSupport::Concern

    included do
      attr_writer :auto_include_context

      class << self
        delegate :auto_include, to: :all
      end
    end

    def initialize_copy(other)
      super
      @auto_include_context = nil
    end

    def auto_include_context
      @auto_include_context ||= Goldiloader::AutoIncludeContext.new.register_model(self)
    end

    def reload(*)
      @auto_include_context = nil
      super
    end

    def goldiload(cache_name = nil, key: self.class.primary_key, &block)
      cache_name ||= block.source_location.join(':')
      auto_include_context.preloaded(self, cache_name: cache_name, key: key, &block)
    end
  end
  ::ActiveRecord::Base.include(::Goldiloader::BasePatch)

  module RelationPatch
    def exec_queries
      return super if loaded? || !auto_include_value

      models = super
      Goldiloader::AutoIncludeContext.register_models(models, eager_load_values)
      models
    end

    def auto_include(auto_include = true)
      spawn.auto_include!(auto_include)
    end

    def auto_include!(auto_include = true)
      self.auto_include_value = auto_include
      self
    end

    def auto_include_value
      @values.fetch(:auto_include, true)
    end

    def auto_include_value=(value)
      if ::Goldiloader::Compatibility.pre_rails_7_2?
        assert_mutability!
      else
        assert_modifiable!
      end
      @values[:auto_include] = value
    end
  end
  ::ActiveRecord::Relation.prepend(::Goldiloader::RelationPatch)

  module MergerPatch
    private

    def merge_single_values
      relation.auto_include_value = other.auto_include_value
      super
    end
  end
  ActiveRecord::Relation::Merger.prepend(::Goldiloader::MergerPatch)

  module AssociationReflectionPatch
    # Note we need to pass the association's target class as an argument since it won't be known
    # outside the context of an association instance for polymorphic associations.
    def eager_loadable?(target_klass)
      @eager_loadable_cache ||= Hash.new do |cache, target_klass_key|
        cache[target_klass_key] = if scope.nil?
                                    # Associations without any scoping options are eager loadable
                                    true
                                  elsif scope.arity > 0
                                    # The scope will be evaluated for every model instance so it can't
                                    # be eager loaded
                                    false
                                  else
                                    scope_info = Goldiloader::ScopeInfo.new(scope_for(target_klass_key.unscoped))
                                    scope_info.auto_include? &&
                                      !scope_info.limit? &&
                                      !scope_info.offset? &&
                                      (!has_one? || !scope_info.order?)
                                  end
      end
      @eager_loadable_cache[target_klass]
    end
  end
  ActiveRecord::Reflection::AssociationReflection.include(::Goldiloader::AssociationReflectionPatch)
  ActiveRecord::Reflection::ThroughReflection.include(::Goldiloader::AssociationReflectionPatch)

  module AssociationPatch
    extend ActiveSupport::Concern

    included do
      class_attribute :default_fully_load
      self.default_fully_load = false
    end

    def auto_include?
      # We only auto include associations that don't have in-memory changes since the
      # Rails association Preloader clobbers any in-memory changes
      !loaded? && target.blank? && eager_loadable?
    end

    def fully_load?
      !loaded? && options.fetch(:fully_load) { self.class.default_fully_load }
    end

    private

    def eager_loadable?
      klass && reflection.eager_loadable?(klass)
    end

    def load_with_auto_include
      return yield unless Goldiloader.enabled?

      if loaded? && !stale_target?
        target
      elsif !auto_include?
        yield
      elsif owner.auto_include_context.size == 1
        # Bypassing the preloader for a single model reduces object allocations by ~5% in benchmarks
        result = yield
        # As of https://github.com/rails/rails/commit/bd3b28f7f181dce53e872daa23dda101498b8fb4
        # ActiveRecord does not use ActiveRecord::Relation#exec_queries to resolve association
        # queries
        Goldiloader::AutoIncludeContext.register_models(result)
        result
      else
        Goldiloader::AssociationLoader.load(owner, reflection.name)
        target
      end
    end
  end
  ::ActiveRecord::Associations::Association.include(::Goldiloader::AssociationPatch)

  module SingularAssociationPatch
    private

    def find_target(...)
      load_with_auto_include { super }
    end
  end
  ::ActiveRecord::Associations::SingularAssociation.prepend(::Goldiloader::SingularAssociationPatch)

  module CollectionAssociationPatch
    # Force these methods to load the entire association for fully_load associations
    [:size, :ids_reader, :empty?].each do |method|
      define_method(method) do |*args, **kwargs, &block|
        load_target if fully_load?
        super(*args, **kwargs, &block)
      end
    end

    def load_target(...)
      load_with_auto_include { super }
    end

    def find_from_target?
      fully_load? || super
    end
  end
  ::ActiveRecord::Associations::CollectionAssociation.prepend(::Goldiloader::CollectionAssociationPatch)

  module ThroughAssociationPatch
    def auto_include?
      # Only auto include through associations if the target association is auto-loadable
      through_association = owner.association(through_reflection.name)
      auto_include_self = super

      # If the current association cannot be auto-included there is nothing we can do
      return false unless auto_include_self

      # If the through association can just be auto-included we're good
      return true if through_association.auto_include?

      # The original logic allowed auto-including when the through association was already loaded
      # and didn't contain new, changed, or destroyed records. However, this can cause scope leakage
      # issues in Rails' Preloader where scopes from one association leak into queries for other
      # associations when multiple through associations share the same through model.
      #
      # Specifically, when the owner model has a default_scope AND there are multiple scoped through
      # associations using the same join table, Rails' Preloader may incorrectly apply scopes/orders
      # from one association to another association's query.
      #
      # To prevent this, we disable the optimization if:
      # 1. The owner model has a default_scope with ordering, AND
      # 2. There are other scoped through associations using the same through association
      return false if has_scope_leakage_risk?

      through_association.loaded? && Array.wrap(through_association.target).none? do |record|
        record.new_record? || record.changed? || record.destroyed?
      end
    end

    private

    def has_scope_leakage_risk?
      check_class = resolve_check_class

      # Only check for risk if owner has a default_scope with ordering
      return false unless class_has_order_default_scope?(check_class)

      # Check if there are other scoped through associations via the same join
      has_other_scoped_through_associations?(check_class)
    end

    def resolve_check_class
      # For STI subclasses, use the base class since that's where associations and default_scopes are defined
      owner_class = owner.class
      owner_class.respond_to?(:base_class) ? owner_class.base_class : owner_class
    end

    def class_has_order_default_scope?(check_class)
      return false unless check_class.respond_to?(:default_scopes)

      # Cache the result per class since default_scopes don't change at runtime
      cache_key = check_class
      @order_scope_cache ||= {}
      return @order_scope_cache[cache_key] if @order_scope_cache.key?(cache_key)

      @order_scope_cache[cache_key] = check_class.default_scopes.any? do |scope|
        # Handle both Proc and ActiveRecord::Scoping::DefaultScope
        scope_proc = scope.is_a?(Proc) ? scope : (scope.respond_to?(:scope) ? scope.scope : nil)
        next false unless scope_proc

        # Evaluate the scope to check if it contains ordering
        begin
          scope_relation = check_class.unscoped.instance_exec(&scope_proc)
          scope_relation.order_values.present?
        rescue StandardError => e
          # If we can't evaluate the scope, be conservative and assume it has ordering
          true
        end
      end
    end

    def has_other_scoped_through_associations?(check_class)
      # Check if there are other through associations that:
      # 1. Use the same through reflection
      # 2. Have their own scopes (not just relying on the target model's default_scope)
      through_name = through_reflection.name
      current_assoc_name = reflection.name

      # Cache the scoped through associations per class+through_name since they don't change at runtime
      cache_key = [check_class, through_name]
      @scoped_through_cache ||= {}

      unless @scoped_through_cache.key?(cache_key)
        @scoped_through_cache[cache_key] = check_class.reflect_on_all_associations.select do |assoc|
          assoc.is_a?(ActiveRecord::Reflection::ThroughReflection) &&
            assoc.through_reflection.name == through_name &&
            assoc.scope.present?
        end.map(&:name).to_set
      end

      # Check if there are any other scoped associations besides the current one
      scoped_assocs = @scoped_through_cache[cache_key]
      scoped_assocs.size > 1 || (scoped_assocs.size == 1 && !scoped_assocs.include?(current_assoc_name))
    end
  end
  ::ActiveRecord::Associations::HasManyThroughAssociation.prepend(::Goldiloader::ThroughAssociationPatch)
  ::ActiveRecord::Associations::HasOneThroughAssociation.prepend(::Goldiloader::ThroughAssociationPatch)

  module CollectionProxyPatch
    # The CollectionProxy just forwards exists? to the underlying scope so we need to intercept this and
    # force it to use size which handles fully_load properly.
    def exists?(*args, **kwargs)
      # We don't fully_load the association when arguments are passed to exists? since Rails always
      # pushes this query into the database without any caching (and it likely not a common
      # scenario worth optimizing).
      if args.empty? && kwargs.empty? && @association.fully_load?
        size > 0
      else
        scope.exists?(*args, **kwargs)
      end
    end
  end
  ::ActiveRecord::Associations::CollectionProxy.prepend(::Goldiloader::CollectionProxyPatch)
end

Goldiloader::AssociationOptions.register
