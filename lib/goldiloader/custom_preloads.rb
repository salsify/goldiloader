# frozen_string_literal: true

module Goldiloader
  module CustomPreloads
    def initialize
      super
      @custom_preloads = nil
    end

    def preloaded(model, cache_name:, key:, &_block)
      unless preloaded?(cache_name)
        ids = models.map do |record|
          record.public_send(key)
        end

        store_preloaded(cache_name, yield(ids))
      end
      fetch_preloaded(cache_name, model, key: key)
    end

    private

    def store_preloaded(cache_name, preloaded_hash)
      @custom_preloads ||= {}
      @custom_preloads[cache_name] = preloaded_hash
    end

    def fetch_preloaded(cache_name, instance, key:)
      @custom_preloads&.dig(cache_name, instance.public_send(key))
    end

    def preloaded?(cache_name)
      @custom_preloads&.key?(cache_name)
    end
  end
end
