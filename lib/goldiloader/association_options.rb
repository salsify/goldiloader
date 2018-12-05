# frozen_string_literal: true

module Goldiloader
  module AssociationOptions
    extend self

    OPTIONS = [:fully_load].freeze

    # This is only used in Rails 5+
    module AssociationBuilderExtension
      def self.build(model, reflection)
        # We have no callbacks to register
      end

      def self.valid_options
        OPTIONS
      end
    end

    def register
      if Goldiloader::Compatibility.rails_4?
        ActiveRecord::Associations::Builder::Association.valid_options.concat(OPTIONS)
      else
        ActiveRecord::Associations::Builder::Association.extensions << AssociationBuilderExtension
      end
    end
  end
end

Goldiloader::AssociationOptions.register
