# encoding: UTF-8

module Goldiloader
  class AutoIncludeContext
    attr_reader :models

    def initialize
      @models = []
    end

    def self.register_models(models, included_associations = nil)
      auto_include_context = Goldiloader::AutoIncludeContext.new
      auto_include_context.register_models(models)

      Array.wrap(included_associations).each do |included_association|
        associations = included_association.is_a?(Hash) ?
            included_association.keys : Array.wrap(included_association)
        nested_associations = included_association.is_a?(Hash) ?
            included_association : Hash.new([])

        associations.each do |association|
          nested_models = models.flat_map do |model|
            model.association(association).target
          end.compact

          register_models(nested_models, nested_associations[association])
        end
      end
    end

    def register_models(models)
      Array.wrap(models).each do |model|
        model.auto_include_context = self
        self.models << model
      end
      self
    end

    alias_method :register_model, :register_models
  end
end
