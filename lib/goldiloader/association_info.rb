module Goldiloader
  class AssociationInfo

    def initialize(association)
      @association = association
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
        @association.options[:finder_sql].present?
      end

      def group?
        @association.options[:group].present?
      end
    end

  end
end
