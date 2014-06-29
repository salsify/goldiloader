# encoding: UTF-8

module Goldiloader
  class AssociationInfo

    def initialize(association)
      @association = association
    end

    def unscope?
      Goldiloader::Compatibility.unscope_query_method_enabled? &&
        @association.association_scope.unscope_values.present?
    end

    def finder_sql?
      Goldiloader::Compatibility.association_finder_sql_enabled? &&
        @association.options[:finder_sql].present?
    end

    if ActiveRecord::VERSION::MAJOR >= 4
      def read_only?
        @association.association_scope.readonly_value.present?
      end

      def offset?
        @association.association_scope.offset_value.present?
      end

      def limit?
        @association.association_scope.limit_value.present?
      end

      def from?
        @association.association_scope.from_value.present?
      end

      def group?
        @association.association_scope.group_values.present?
      end

      def joins?
        # Yuck - Through associations will always have a join for *each* 'through' table
        (@association.association_scope.joins_values.size - num_through_joins) > 0
      end

      private

      def num_through_joins
        association = @association
        count = 0
        while association.is_a?(ActiveRecord::Associations::ThroughAssociation)
          count += 1
          association = association.owner.association(association.through_reflection.name)
        end
        count
      end
    else
      def read_only?
        @association.options[:readonly].present?
      end

      def offset?
        @association.options[:offset].present?
      end

      def limit?
        @association.options[:limit].present?
      end

      def from?
        false
      end

      def group?
        @association.options[:group].present?
      end

      def joins?
        # Rails 3 didn't support joins for associations
        false
      end
    end

  end
end
