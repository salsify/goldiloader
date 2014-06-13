# encoding: UTF-8

require 'goldiloader/association_helper'
require 'goldiloader/model_registry'

ActiveRecord::Relation.class_eval do

  def exec_queries_with_auto_include
    return exec_queries_without_auto_include if loaded?

    records = exec_queries_without_auto_include
    Goldiloader::AssociationHelper.extend_associations(Goldiloader::ModelRegistry.new, records, [])
    records
  rescue Exception => e
    # TODO: Remove
    STDERR.puts "#{e.message}\n#{e.backtrace.join("\n")}"
    raise
  end

  alias_method_chain :exec_queries, :auto_include
end
