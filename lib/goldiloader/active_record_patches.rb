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
      cache_name ||= begin
        # Interpolating builds the same name as Array#join(':') but is faster
        path, line = block.source_location
        "#{path}:#{line}"
      end
      auto_include_context.preloaded(self, cache_name: cache_name, key: key, &block)
    end
  end
  ::ActiveRecord::Base.include(::Goldiloader::BasePatch)

  module QueryingPatch
    def find_by_sql(sql, binds = [], preparable: nil, allow_retry: false, auto_include: true, &block)
      models = super(sql, binds, preparable: preparable, allow_retry: allow_retry, &block)
      Goldiloader::AutoIncludeContext.register_models(models) if auto_include
      models
    end

    # Rails 7.2's async_find_by_sql takes no allow_retry: keyword
    def async_find_by_sql(sql, binds = [], auto_include: true, **options, &block)
      super(sql, binds, **options, &block).then do |models|
        Goldiloader::AutoIncludeContext.register_models(models) if auto_include
        models
      end
    end
  end
  ::ActiveRecord::Base.singleton_class.prepend(::Goldiloader::QueryingPatch)

  module RelationPatch
    def exec_queries
      return super unless auto_include_value

      models = super
      Goldiloader::AutoIncludeContext.register_models(
        models,
        eager_loading? ? eager_load_values | includes_values : nil
      )
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
      assert_modifiable!
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

  module ThroughReflectionPatch
    # Scope values that Rails keeps (`distinct`) or whose loss doesn't change the records the association holds
    SCOPE_VALUES_SAFE_TO_DROP = [
      :distinct, :auto_include, :annotate, :extending, :preload, :includes, :references, :optimizer_hints, :create_with
    ].freeze
    private_constant :SCOPE_VALUES_SAFE_TO_DROP

    # Whether reusing loaded records loses part of this association's own scope or its `source_type`, as Rails
    # does when it preloads it from records already loaded: https://github.com/salsify/goldiloader/issues/166
    def scope_lost_by_reusing_loaded_records?(target_klass)
      @scope_lost_by_reusing_loaded_records_cache ||= Hash.new do |cache, target_klass_key|
        cache[target_klass_key] = if options[:source_type]
                                    true
                                  elsif scope.nil?
                                    false
                                  elsif scope.arity > 0
                                    true
                                  else
                                    # Compare with the unscoped values, which hold the type condition of an STI
                                    # subclass
                                    unscoped = target_klass_key.unscoped
                                    scope_for(unscoped).values.except(*SCOPE_VALUES_SAFE_TO_DROP) !=
                                      unscoped.values.except(*SCOPE_VALUES_SAFE_TO_DROP)
                                  end
      end
      @scope_lost_by_reusing_loaded_records_cache[target_klass]
    end
  end
  ActiveRecord::Reflection::ThroughReflection.include(::Goldiloader::ThroughReflectionPatch)

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
      elsif owner.auto_include_context.size == 1 || !auto_include?
        # Bypassing the preloader for a single model reduces object allocations by ~5% in benchmarks.
        # The loaded models need no registering here: as of
        # https://github.com/rails/rails/commit/bd3b28f7f181dce53e872daa23dda101498b8fb4 association queries
        # go through find_by_sql (StatementCache#execute), which registers them, rather than Relation#exec_queries
        yield
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
    def size(...)
      load_target if fully_load?
      super
    end

    def ids_reader(...)
      load_target if fully_load?
      super
    end

    def empty?(...)
      load_target if fully_load?
      super
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

      # If the through association was already loaded and does not contain new, changed, or destroyed records
      # we are also able to auto-include the association. It means it has only already been read or changes are
      # already persisted.
      through_association.loaded? && Array.wrap(through_association.target).none? do |record|
        record.new_record? || record.changed? || record.destroyed?
      end
    end

    private

    # Rails versions with https://github.com/rails/rails/pull/59599 query the source records of a single level
    # through association instead of reusing loaded ones when its scope or `source_type` filters them
    RAILS_REQUERIES_FILTERED_SOURCE =
      ::ActiveRecord::Associations::Preloader::ThroughAssociation.const_defined?(:SOURCE_REUSING_SCOPE_VALUES, false)
    private_constant :RAILS_REQUERIES_FILTERED_SOURCE

    def eager_loadable?
      super && !(reflection.through_reflection? && other_class_than_source?(reflection, klass)) &&
        !scope_lost_by_reusing_loaded_records?(owner, reflection, klass)
    end

    # Rails preloads a through association with a `class_name` other than its source's as the source's class
    def other_class_than_source?(chain_reflection, target_klass)
      source_reflection = chain_reflection.source_reflection
      !source_reflection.polymorphic? && target_klass != source_reflection.klass
    end

    # A sibling association might have loaded the records this association would reuse e.g. `tags` loads the
    # `post_tags` and their `tag` that `tags_owned_by_users` goes through too. Rails reuses a loaded association
    # even when it holds nil or nothing, at every level of a nested through association, and loses the scope of
    # the association it preloads. Through records loaded without their source records are fine: the source
    # records are queried with the association's scope (a scope with a condition on the through table then fails,
    # as it does without Goldiloader).
    def scope_lost_by_reusing_loaded_records?(record, chain_reflection, target_klass = nil)
      return false if loaded_association?(record, chain_reflection.name) || !chain_reflection.through_reflection?

      through_reflection = chain_reflection.through_reflection
      source_reflection = chain_reflection.source_reflection
      return true if scope_lost_by_reusing_loaded_records?(record, through_reflection)

      target_klass ||= chain_reflection.klass
      # With a `class_name` other than the source's class, the target class (and its default scope) is lost too
      other_class = other_class_than_source?(chain_reflection, target_klass)
      scope_lost = other_class || chain_reflection.scope_lost_by_reusing_loaded_records?(target_klass)
      return false unless scope_lost || source_reflection.through_reflection?

      any_reused_record?(record, through_reflection) do |through_record|
        (scope_lost && reuses_loaded_source?(through_record, chain_reflection, other_class)) ||
          scope_lost_by_reusing_loaded_records?(through_record, source_reflection)
      end
    end

    # Whether preloading `chain_reflection` reuses something loaded on `through_record`, one of its through
    # records, in a way Rails doesn't guard against
    def reuses_loaded_source?(through_record, chain_reflection, other_class)
      source_reflection = chain_reflection.source_reflection
      # Rails with the fix still reuses what's loaded further down a nested through association, and source
      # records of another class
      return false if RAILS_REQUERIES_FILTERED_SOURCE && !other_class &&
                      !chain_reflection.through_reflection.through_reflection? &&
                      !source_reflection.through_reflection?

      # Without the fix, through records are filtered by `source_type` only when the first owner has them loaded
      chain_reflection.options[:source_type].present? || reuses_loaded_association?(through_record, source_reflection)
    end

    # Whether Rails reuses a loaded association instead of querying when preloading `chain_reflection` on
    # `record`. For a through association that isn't loaded, Rails reuses whatever is loaded at each level of its
    # chain e.g. the loaded `post_tags` of a blog's loaded `posts` for `has_many :blog_post_tags, through: :posts`.
    def reuses_loaded_association?(record, chain_reflection)
      return true if loaded_association?(record, chain_reflection.name)
      return false unless chain_reflection.through_reflection?

      any_reused_record?(record, chain_reflection.through_reflection) do |through_record|
        reuses_loaded_association?(through_record, chain_reflection.source_reflection)
      end
    end

    # Whether the block returns true for any record Rails reuses when preloading `chain_reflection` on `record`
    def any_reused_record?(record, chain_reflection, &block)
      if loaded_association?(record, chain_reflection.name)
        target = record.association(chain_reflection.name).target
        target.is_a?(Array) ? target.any?(&block) : !target.nil? && yield(target)
      elsif chain_reflection.through_reflection?
        any_reused_record?(record, chain_reflection.through_reflection) do |through_record|
          any_reused_record?(through_record, chain_reflection.source_reflection, &block)
        end
      else
        false
      end
    end

    # Checks association_cached? first so that no association gets instantiated
    def loaded_association?(record, name)
      record.association_cached?(name) && record.association(name).loaded?
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
