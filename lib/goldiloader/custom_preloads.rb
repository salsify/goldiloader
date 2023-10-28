# frozen_string_literal: true

module Goldiloader
  module CustomPreloads
    def preloaded(instance, key, primary_key: :id, &_block)
      unless preloaded?(key)
        ids = models.map do |record|
          record.public_send(primary_key)
        end

        store_preloaded(key, yield(ids))
      end
      fetch_preloaded(key, instance, primary_key: primary_key)
    end

    def store_preloaded(key, preloads_hash)
      @preloads ||= {}
      @preloads[key] = preloads_hash
    end

    def fetch_preloaded(key, instance, primary_key: :id)
      @preloads&.dig(key, instance.public_send(primary_key))
    end

    def preloaded?(key)
      @preloads&.key?(key)
    end
  end
end
