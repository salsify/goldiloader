# frozen_string_literal: true

module Goldiloader
  module CustomPreloads
    def initialize
      super
      @custom_preloads = nil
    end

    def preloaded(model, cache_name:, key:, &block)
      @custom_preloads ||= {}
      preloaded_hash = @custom_preloads.fetch(cache_name) do
        ids = models.map do |record|
          key_from_record(record, key)
        end

        # We're using instance_exec instead of a simple yield to make sure that the
        # given block does not have any references to the model instance as this might
        # lead to unexpected results. The block will be executed in the context of the
        # class of the model instead.
        @custom_preloads[cache_name] = model.class.instance_exec(ids, &block)
      end
      preloaded_hash[key_from_record(model, key)]
    end

    private

    def key_from_record(record, key_or_key_list)
      if key_or_key_list.is_a?(Array)
        # allow passing an array of keys that will be collected from the record
        key_or_key_list.map do |key|
          record.public_send(key)
        end
      else
        record.public_send(key_or_key_list)
      end
    end
  end
end
