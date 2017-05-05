# encoding: UTF-8

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
      if ::ActiveRecord::VERSION::MAJOR >= 5
        ActiveRecord::Associations::Builder::Association.extensions << AssociationBuilderExtension
      else
        ActiveRecord::Associations::Builder::Association.valid_options.concat(OPTIONS)
      end
    end

    private
  end
end

Goldiloader::AssociationOptions.register
