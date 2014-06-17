# encoding: UTF-8

module Goldiloader
  class ModelRegistry
    def initialize
      @registry = {}
    end

    def register(record, association_path)
      key = registry_key(record, association_path)
      @registry[key] ||= []
      @registry[key] << record
    end

    # Returns all models with the same base class loaded from the same association path
    def peers(record, association_path)
      @registry.fetch(registry_key(record, association_path), [])
    end

    private

    def registry_key(record, association_path)
      [record.class.base_class, association_path]
    end
  end
end
