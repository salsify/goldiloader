# frozen_string_literal: true

module Goldiloader
  class AutoIncludeContext
    EMPTY_HASH = {}.freeze

    attr_reader :models

    delegate :size, to: :models

    def initialize
      @models = []
    end

    def self.register_models(models, included_associations = nil)
      # A lone model builds the same context lazily, so loading one record allocates none upfront
      return if models.size <= 1 && included_associations.blank?

      auto_include_context = Goldiloader::AutoIncludeContext.new
      auto_include_context.register_models(models)
      return if included_associations.blank?

      Array.wrap(included_associations).each do |included_association|
        associations = if included_association.is_a?(Hash)
                         included_association.keys
                       else
                         Array.wrap(included_association)
                       end
        nested_associations = if included_association.is_a?(Hash)
                                included_association
                              else
                                EMPTY_HASH
                              end

        associations.each do |association|
          nested_models = models.flat_map do |model|
            model.association(association).target
          end
          nested_models.compact!

          register_models(nested_models, nested_associations[association])
        end
      end
    end

    def register_models(models)
      # Don't use Array() or Array.wrap() because they will check respond_to?(:to_ary)
      # which for ActiveStorage::Attachment will delegate to the blob association which
      # triggers an infinite eager loading loop on the association
      models = [models] unless models.is_a?(Array)
      models.each do |model|
        next if model.nil?

        model.auto_include_context = self
        self.models << model
      end
      self
    end

    alias_method :register_model, :register_models

    prepend Goldiloader::CustomPreloads
  end
end
