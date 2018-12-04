# frozen_string_literal: true

module Goldiloader
  class ScopeInfo
    attr_reader :scope

    def initialize(scope)
      @scope = scope
    end

    def offset?
      scope.offset_value.present?
    end

    def limit?
      scope.limit_value.present?
    end

    def auto_include?
      scope.auto_include_value
    end

    def from?
      if ActiveRecord::VERSION::MAJOR >= 5
        scope.from_clause.present?
      else
        scope.from_value.present?
      end
    end

    def group?
      scope.group_values.present?
    end

    def order?
      scope.order_values.present?
    end
  end
end
