# encoding: UTF-8

module Goldiloader
  class AutoIncludeContext < Struct.new(:model_registry, :association_path)
    def self.create_empty
      Goldiloader::AutoIncludeContext.new(Goldiloader::ModelRegistry.new, [])
    end

    def register_models(models)
      Array.wrap(models).each do |model|
        model.auto_include_context = self
        model_registry.register(model, association_path)
      end
    end
  end
end
