# encoding: UTF-8

require 'goldiloader/association_helper'
require 'goldiloader/model_registry'

module Goldiloader
  module RelationMethods
    def exec_queries
      return super if loaded?

      records = super
      Goldiloader::AssociationHelper.extend_associations(Goldiloader::ModelRegistry.new, records, [])
      records
    rescue Exception => e
      # TODO: Remove
      STDERR.puts "#{e.message}\n#{e.backtrace.join("\n")}"
      raise
    end
  end
end
