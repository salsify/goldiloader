# encoding: UTF-8

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
      # Note: Don't use get_value because that doesn't work properly with defaulting boolean values
      @values.fetch(:auto_include, true)
    end

    def auto_include_value=(value)
      if Goldiloader::Compatibility.rails_4?
        raise ::ActiveRecord::Relation::ImmutableRelation if @loaded
        check_cached_relation
        @values[:auto_include] = value
      elsif Goldiloader::Compatibility.rails_5_0?
        assert_mutability!
        @values[:auto_include] = value
      else
        set_value(:auto_include, value)
      end
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
      association_info = Goldiloader::AssociationInfo.new(self)
      !association_info.limit? &&
        !association_info.offset? &&
        !association_info.group? &&
        !association_info.from? &&
        !association_info.instance_dependent? &&
        association_info.auto_include?
    end

    def load_with_auto_include
      if loaded? && !stale_target?
        target
      elsif auto_include?
        Goldiloader::AssociationLoader.load(owner, reflection.name)
        target
      else
        yield
      end
    end
  end
  ::ActiveRecord::Associations::Association.include(::Goldiloader::AssociationPatch)

  module SingularAssociationPatch
    private

    def find_target(*args)
      load_with_auto_include { super }
    end
  end
  ::ActiveRecord::Associations::SingularAssociation.prepend(::Goldiloader::SingularAssociationPatch)

  module CollectionAssociationPatch
    # Force these methods to load the entire association for fully_load associations
    association_methods = [:size, :ids_reader, :empty?]
    if Goldiloader::Compatibility::ACTIVE_RECORD_VERSION < ::Gem::Version.new('5.1')
      association_methods.concat([:first, :second, :third, :fourth, :fifth, :last])
    end

    association_methods.each do |method|
      define_method(method) do |*args, &block|
        load_target if fully_load?
        super(*args, &block)
      end
    end

    def load_target(*args)
      load_with_auto_include { super }
    end

    if Goldiloader::Compatibility::ACTIVE_RECORD_VERSION >= ::Gem::Version.new('5.1')
      def find_from_target?
        fully_load? || super
      end
    end
  end
  ::ActiveRecord::Associations::CollectionAssociation.prepend(::Goldiloader::CollectionAssociationPatch)

  module ThroughAssociationPatch
    def auto_include?
      # Only auto include through associations if the target association is auto-loadable
      through_association = owner.association(through_reflection.name)
      through_association.auto_include? && super
    end
  end
  ::ActiveRecord::Associations::HasManyThroughAssociation.prepend(::Goldiloader::ThroughAssociationPatch)
  ::ActiveRecord::Associations::HasOneThroughAssociation.prepend(::Goldiloader::ThroughAssociationPatch)

  module CollectionProxyPatch
    # The CollectionProxy just forwards exists? to the underlying scope so we need to intercept this and
    # force it to use size which handles fully_load properly.
    def exists?(*args)
      # We don't fully_load the association when arguments are passed to exists? since Rails always
      # pushes this query into the database without any caching (and it likely not a common
      # scenario worth optimizing).
      if args.empty? && @association.fully_load?
        size > 0
      else
        scope.exists?(*args)
      end
    end
  end
  ::ActiveRecord::Associations::CollectionProxy.prepend(::Goldiloader::CollectionProxyPatch)
end
