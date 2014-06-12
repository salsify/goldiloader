# encoding: UTF-8

require 'goldiloader/model_registry'
require 'goldiloader/association_options'

module Goldiloader
  module AssociationHelper
    extend self

    # Wraps all association methods for the given models to lazily eager load the association
    # for all similar models in the model_registry whenever values are read from the association.
    def extend_associations(model_registry, models, association_path)
      # TODO: Remove me
      debug(association_path.size) do
        "Registering #{model_string(models)} for path #{association_path}" if models.present?
      end

      Array.wrap(models).each do |model|
        model_registry.register(model, association_path)

        model.define_singleton_method(:association) do |name|
          # This will only return a nil association the first time when it is not in
          # the association cache
          association = association_instance_get(name)
          if association.nil?
            association = super(name)
            AssociationHelper.extend_association(model_registry, association, association_path + [name]) unless association.nil?
          end
          association
        end
      end
    end

    def extend_association(model_registry, association, association_path)
      if association.is_a?(::ActiveRecord::Associations::CollectionAssociation)
        extend_collection_association(model_registry, association, association_path)
      else
        extend_singular_association(model_registry, association, association_path)
      end
    end

    def extend_singular_association(model_registry, association, association_path)
      # Override find_target to load the association on all similar loaded objects
      association.define_singleton_method(:find_target) do |*args|
        unless loaded?
          if Goldiloader::AssociationOptions.auto_include?(self)
            AssociationHelper.load_association(model_registry, association.owner, association_path)
          else
            super(*args)
            AssociationHelper.extend_associations(ModelRegistry.new, target, association_path)
          end
        end
        target
      end
    end

    def extend_collection_association(model_registry, association, association_path)
      # Override load_target to load the association on all similar loaded objects
      association.define_singleton_method(:load_target) do |*args|
        unless loaded?
          if Goldiloader::AssociationOptions.auto_include?(self)
            AssociationHelper.load_association(model_registry, association.owner, association_path)
          else
            super(*args)
            AssociationHelper.extend_associations(ModelRegistry.new, target, association_path)
          end
        end
        target
      end

      # Force these methods to work off a fully loaded association
      if Goldiloader::AssociationOptions.auto_include?(association)
        [:first, :last, :size, :ids_reader].each do |method|
          association.define_singleton_method(method) do |*args|
            load_target unless loaded?
            super(*args)
          end
        end

        # The CollectionProxy just forwards exists? to the underlying scope so we need to intercept this and
        # force it to use any? which will use our patched find_target. CollectionProxy undefines define_singleton_method
        # (along with most instance methods) so we need to use #proxy_extend and a module to inject this
        # behavior.
        exists_module = Module.new do
          def exists?
            size > 0
          end
        end

        if ::ActiveRecord::VERSION::MAJOR >= 4
          association.reader.extend(exists_module)
        else
          association.proxy.proxy_extend(exists_module)
        end
      end
    end

    def load_association(model_registry, model, association_path)
      *model_path, association_name = *association_path
      models = model_registry.peers(model, model_path).select do |model|
        load_association?(model, association_name)
      end

      # TODO: Remove Me
      debug(association_path.size) { "Eager loading #{association_path} for #{model_string(models)}" }

      if ::ActiveRecord::VERSION::MAJOR >= 4
        ::ActiveRecord::Associations::Preloader.new.preload(models, [association_name])
      else
        ::ActiveRecord::Associations::Preloader.new(models, [association_name]).run
      end

      # TODO: Remove Me
      debug(association_path.size) do
        unloaded_models = models.select { |model| load_association?(model, association_name) }
        "Failed to eager load #{association_path} for #{model_string(unloaded_models)}" if unloaded_models.present?
      end

      # TODO: Remove Me
      debug(association_path.size) do
        loaded_models = models.reject { |model| load_association?(model, association_name) }
        "Done eager loading #{association_path} for #{model_string(loaded_models)}"
      end

      associated_models = models.map { |model| model.send(association_name) }.flatten.compact.uniq
      extend_associations(model_registry, associated_models, association_path)
    end

    # TODO: Remove me
    def debug(indent)
      if ENV.fetch('DEBUG_AUTO_EAGER_LOAD', 'false') == 'true'
        result = yield
        STDERR.puts "#{' ' * indent}#{result}" if result.present?
      end
    end

    # TODO: Remove me
    def model_string(models)
      models = Array.wrap(models)
      return "[]" unless models.present?

      models = models.sort_by(&:id)

      str = "#{models.first.class}("
      str << models.map { |model| "#{model.id}:#{model.object_id.to_s(16)}" }.join(", ")
      str << ")"
      str
    end

    def load_association?(model, association_name)
      # Need to make sure the model actually has the association which won't always
      # be the case in STI hierarchies e.g. only a subclass might have the association
      model.class.reflect_on_association(association_name).present? &&
        !model.association(association_name).loaded?
    end

  end
end
