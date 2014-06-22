# encoding: UTF-8

module Goldiloader
  module AssociationLoader
    extend self

    def load(model_registry, model, association_path)
      *model_path, association_name = *association_path
      models = model_registry.peers(model, model_path).select do |model|
        load?(model, association_name)
      end

      if Gem::Version.new(::ActiveRecord::VERSION::STRING) >= Gem::Version.new('4.1')
        ::ActiveRecord::Associations::Preloader.new.preload(models, [association_name])
      else
        ::ActiveRecord::Associations::Preloader.new(models, [association_name]).run
      end

      associated_models = associated_models(models, association_name)
      # Workaround Rails #15853 by setting models read only
      mark_read_only(associated_models) if read_only?(models, association_name)
      auto_include_context = Goldiloader::AutoIncludeContext.new(model_registry, association_path)
      auto_include_context.register_models(associated_models)
    end

    private

    def mark_read_only(models)
      models.each(&:readonly!)
    end

    def read_only?(models, association_name)
      model = first_model_with_association(models, association_name)
      if model.nil?
        false
      elsif ActiveRecord::VERSION::MAJOR >= 4
        model.association(association_name).association_scope.readonly_value
      else
        model.class.reflect_on_association(association_name).options[:readonly]
      end
    end

    def first_model_with_association(models, association_name)
      models.find { |model| has_association?(model, association_name) }
    end

    def associated_models(models, association_name)
      # We can't just do model.send(association_name) because the association method may have been
      # overridden
      models.map { |model| model.association(association_name).target }.flatten.compact.uniq
    end

    def load?(model, association_name)
      # Need to make sure the model actually has the association which won't always
      # be the case in STI hierarchies e.g. only a subclass might have the association
      has_association?(model, association_name) &&
        model.association(association_name).auto_include?
    end

    def has_association?(model, association_name)
      model.class.reflect_on_association(association_name).present?
    end
  end
end
