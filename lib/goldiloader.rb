# encoding: UTF-8

require 'active_support/all'
require 'active_record'
require 'goldiloader/compatibility'
require 'goldiloader/association_helper'
require 'goldiloader/relation_methods'

Goldiloader::AssociationHelper.register_association_option

class ActiveRecord::Base
  class << self

    def scoped_with_auto_include(*args)
      result = scoped_without_auto_include(*args)
      unless result.is_a?(Goldiloader::RelationMethods)
        result = result.clone.extend(Goldiloader::RelationMethods)
      end
      result
    end

    alias_method_chain :scoped, :auto_include
  end
end
