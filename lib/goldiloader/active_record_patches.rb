# encoding: UTF-8

module Goldiloader
  module BasePatch
    extend ActiveSupport::Concern

    included do
      attr_writer :auto_include_context
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

    module ClassMethods
      # In Rails >= 4.1 has_and_belongs_to_many associations create a has_many associations
      # under the covers so we need to make sure to propagate the auto_include option to that
      # association
      def has_and_belongs_to_many(name, scope = nil, options = {}, &extension)
        if scope.is_a?(Hash)
          options = scope
          scope = nil
        end

        result = super(name, scope, options, &extension)
        if options.include?(:auto_include)
          _reflect_on_association(name).options[:auto_include] = options[:auto_include]
        end
        result
      end
    end
  end
  ::ActiveRecord::Base.include(::Goldiloader::BasePatch)

  module RelationPatch
    def exec_queries
      return super if loaded?

      models = super
      Goldiloader::AutoIncludeContext.register_models(models, eager_load_values)
      models
    end
  end
  ::ActiveRecord::Relation.prepend(::Goldiloader::RelationPatch)

  module AssociationPatch
    extend ActiveSupport::Concern

    included do
      class_attribute :default_auto_include, :default_fully_load
      self.default_auto_include = true
      self.default_fully_load = false
    end

    def auto_include?
      # We only auto include associations that don't have in-memory changes since the
      # Rails association Preloader clobbers any in-memory changes
      !loaded? && target.blank? && options.fetch(:auto_include) { self.class.default_auto_include } && eager_loadable?
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
        !association_info.instance_dependent?
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
