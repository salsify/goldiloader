# encoding: UTF-8

require 'active_support/all'
require 'active_record'
require 'goldiloader/compatibility'
require 'goldiloader/association_options'
require 'goldiloader/association_helper'
require 'goldiloader/relation_overrides'

Goldiloader::AssociationOptions.register

class ActiveRecord::Base
  class << self

    if ::ActiveRecord::VERSION::MAJOR >= 4
      def all_with_auto_include(*args)
        result = all_without_auto_include(*args)
        unless result.is_a?(Goldiloader::RelationOverrides)
          result = result.clone.extend(Goldiloader::RelationOverrides)
        end
        result
      end

      alias_method_chain :all, :auto_include
    else
      def scoped_with_auto_include(*args)
        result = scoped_without_auto_include(*args)
        unless result.is_a?(Goldiloader::RelationOverrides)
          result = result.clone.extend(Goldiloader::RelationOverrides)
        end
        result
      end

      alias_method_chain :scoped, :auto_include
    end

  end
end
