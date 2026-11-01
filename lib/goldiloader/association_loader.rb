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

    def suggest(reflection)
      logger = ::ActiveRecord::Base.logger
      return unless logger&.info?

      message = +"Goldiloader suggests eager loading #{reflection.active_record.name}##{reflection.name}"
      location = ::ActiveRecord::LogSubscriber.backtrace_cleaner.clean(caller(1).lazy).first
      message << ", called from #{location}" if location
      logger.info(message)
    end

    private

    def eager_load(models, association_name)
      ::ActiveRecord::Associations::Preloader.new(records: models, associations: [association_name]).call
    end

    def load?(model, association_name)
      # Need to make sure the model actually has the association which won't always
      # be the case in STI hierarchies e.g. only a subclass might have the association
      has_association?(model, association_name) &&
        model.association(association_name).auto_include?
    end

    def has_association?(model, association_name) # rubocop:disable Naming/PredicatePrefix
      model.class.reflect_on_association(association_name).present?
    end
  end
end
