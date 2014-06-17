# encoding: UTF-8

module Goldiloader
  module AssociationOptions
    extend self

    OPTIONS = [:auto_include, :fully_load]

    def register
      if ::ActiveRecord::VERSION::MAJOR >= 4
        ActiveRecord::Associations::Builder::Association.valid_options.concat(OPTIONS)
      else
        # Each subclass of CollectionAssociation will have its own copy of valid_options so we need
        # to register the valid option for each one.
        collection_association_classes.each do |assoc_class|
          assoc_class.valid_options.concat(OPTIONS)
        end
      end
    end

    private

    def collection_association_classes
      # Association.descendants doesn't work well with lazy classloading :(
      [
        ActiveRecord::Associations::Builder::Association,
        ActiveRecord::Associations::Builder::BelongsTo,
        ActiveRecord::Associations::Builder::HasAndBelongsToMany,
        ActiveRecord::Associations::Builder::HasMany,
        ActiveRecord::Associations::Builder::HasOne,
        ActiveRecord::Associations::Builder::SingularAssociation
      ]
    end
  end
end

Goldiloader::AssociationOptions.register
