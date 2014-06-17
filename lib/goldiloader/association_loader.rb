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

      associated_models = models.map { |model| model.send(association_name) }.flatten.compact.uniq
      auto_include_context = Goldiloader::AutoIncludeContext.new(model_registry, association_path)
      auto_include_context.register_models(associated_models)
    end

    private

    def load?(model, association_name)
      # Need to make sure the model actually has the association which won't always
      # be the case in STI hierarchies e.g. only a subclass might have the association
      !model.destroyed? &&
        model.class.reflect_on_association(association_name).present? &&
        model.association(association_name).auto_include?
    end

  end
end
