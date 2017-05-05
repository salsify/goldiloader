# encoding: UTF-8

module Goldiloader
  class AssociationInfo

    def initialize(association)
      @association = association
    end

    delegate :association_scope, :reflection, to: :@association

    def offset?
      association_scope && association_scope.offset_value.present?
    end

    def limit?
      association_scope && association_scope.limit_value.present?
    end

    def auto_include?
      association_scope.nil? || association_scope.auto_include_value
    end

    def from?
      if ActiveRecord::VERSION::MAJOR >= 5
        association_scope && association_scope.from_clause.present?
      else
        association_scope && association_scope.from_value.present?
      end
    end

    def group?
      association_scope && association_scope.group_values.present?
    end

    def instance_dependent?
      reflection.scope.present? && reflection.scope.arity > 0
    end
  end
end
