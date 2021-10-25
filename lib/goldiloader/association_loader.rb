# frozen_string_literal: true

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
      if Goldiloader::Compatibility.pre_rails_7?
        ::ActiveRecord::Associations::Preloader.new.preload(models, [association_name])
      else
        ::ActiveRecord::Associations::Preloader.new(records: models, associations: [association_name]).call
      end
    end

    def load?(model, association_name)
      # Need to make sure the model actually has the association which won't always
      # be the case in STI hierarchies e.g. only a subclass might have the association
      has_association?(model, association_name) &&
        model.association(association_name).auto_include?
    end

    def has_association?(model, association_name) # rubocop:disable Naming/PredicateName
      model.class.reflect_on_association(association_name).present?
    end
  end
end
