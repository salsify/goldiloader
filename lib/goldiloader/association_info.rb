# encoding: UTF-8

module Goldiloader
  class AssociationInfo

    def initialize(association)
      @association = association
    end

    def finder_sql?
      Goldiloader::Compatibility.association_finder_sql_enabled? &&
        association_options[:finder_sql].present?
    end

    if ActiveRecord::VERSION::MAJOR >= 4
      delegate :association_scope, :reflection, to: :@association

      def read_only?
        association_scope && association_scope.readonly_value.present?
      end

      def offset?
        association_scope && association_scope.offset_value.present?
      end

      def limit?
        association_scope && association_scope.limit_value.present?
      end

      def from?
        association_scope && association_scope.from_value.present?
      end

      def group?
        association_scope && association_scope.group_values.present?
      end

      def joins?
        # Yuck - Through associations will always have a join for *each* 'through' table
        association_scope && (association_scope.joins_values.size - num_through_joins) > 0
      end

      def uniq?
        association_scope && association_scope.uniq_value
      end

      def instance_dependent?
        reflection.scope.present? && reflection.scope.arity > 0
      end

      def unscope?
        Goldiloader::Compatibility.unscope_query_method_enabled? &&
            association_scope &&
            association_scope.unscope_values.present?
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
        association_options[:readonly].present?
      end

      def offset?
        association_options[:offset].present?
      end

      def limit?
        association_options[:limit].present?
      end

      def from?
        false
      end

      def group?
        association_options[:group].present?
      end

      def joins?
        # Rails 3 didn't support joins for associations
        false
      end

      def uniq?
        association_options[:uniq]
      end

      def instance_dependent?
        # Rails 3 didn't support this
        false
      end

      def unscope?
        # Rails 3 didn't support this
        false
      end
    end

    private

    def association_options
      @association.options
    end
  end
end
