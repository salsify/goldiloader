# frozen_string_literal: true

module Goldiloader
  # Reads models from Rails.cache with their automatic eager loading reset on a cache hit
  class Cache
    class << self
      # Rails.cache.fetch for a block returning a model, an array of models or nil
      def fetch(name, options = nil)
        cache_hit = true
        result = Rails.cache.fetch(name, options) do |*args|
          cache_hit = false
          value = yield(*args)
          # Checked before Rails caches it
          models(value)
          value
        end
        Goldiloader.reset_auto_include_context(models(result)) if cache_hit
        result
      end

      private

      def models(value)
        models = value.is_a?(Array) ? value : [value]
        invalid = models.find { |model| !model.nil? && !model.is_a?(::ActiveRecord::Base) }
        unless invalid.nil?
          raise ArgumentError.new('Goldiloader::Cache.fetch supports a model, an array of models or nil, ' \
                                  "not #{invalid.class}")
        end

        models
      end
    end
  end
end
