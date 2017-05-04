# encoding: UTF-8

module Goldiloader
  module AssociationLoader
    extend self

    def load(model, association_name)
      models = model.auto_include_context.models.select do |peer|
        load?(peer, association_name)
      end

      eager_load(models, association_name)
    end

    private

    def eager_load(models, association_name)
      ::ActiveRecord::Associations::Preloader.new.preload(models, [association_name])
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
