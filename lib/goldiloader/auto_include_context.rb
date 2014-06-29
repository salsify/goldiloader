# encoding: UTF-8

module Goldiloader
  class AutoIncludeContext
    attr_reader :models

    def initialize
      @models = []
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
