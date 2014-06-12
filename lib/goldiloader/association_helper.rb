# encoding: UTF-8

module Goldiloader
  module AssociationHelper
    extend self

    def register_association_option
      # Each subclass of CollectionAssociation will have its own copy of valid_options so we need
      # to register the valid option for each one.
      collection_association_classes.each do |assoc_class|
        assoc_class.valid_options << :auto_include
      end
    end

    # Wraps all association methods for the given records to lazily eager load the association
    # for all similar records in the load_context whenever values are read from the association.
    def extend_associations(record_registry, records, association_path)
      # TODO: Remove me
      debug(association_path.size) do
        "Registering #{record_string(records)} for path #{association_path}" if records.present?
      end

      Array.wrap(records).each do |record|
        record_registry[registry_key(record, association_path)] ||= []
        record_registry[registry_key(record, association_path)] << record

        record.define_singleton_method(:association) do |name|
          # This will only return a nil association the first time when it is not in
          # the association cache
          association = association_instance_get(name)
          if association.nil?
            association = super(name)
            AssociationHelper.extend_association(record_registry, association, association_path + [name])
          end
          association
        end
      end
    end

    def extend_association(record_registry, association, association_path)
      if association.is_a?(ActiveRecord::Associations::CollectionAssociation)
        extend_collection_association(record_registry, association, association_path)
      else
        extend_singular_association(record_registry, association, association_path)
      end
    end

    def extend_singular_association(record_registry, association, association_path)
      # Override find_target to load the association on all similar loaded objects
      association.define_singleton_method(:find_target) do |*args|
        AssociationHelper.load_association(record_registry, association.owner, association_path) unless loaded?
        target
      end
    end

    def extend_collection_association(record_registry, association, association_path)
      # Override load_target to load the association on all similar loaded objects
      association.define_singleton_method(:load_target) do |*args|
        unless loaded?
          if association.options[:auto_include]
            AssociationHelper.load_association(record_registry, association.owner, association_path)
          else
            super(*args)
            AssociationHelper.extend_associations(record_registry, target, association_path)
          end
        end
        target
      end

      # Force these methods to work off a fully loaded association
      if association.options[:auto_include]
        [:first, :last, :size, :ids_reader].each do |method|
          association.define_singleton_method(method) do |*args|
            load_target unless loaded?
            super(*args)
          end
        end

        # The CollectionProxy just forwards exists? to the underlying scope so we need to intercept this and
        # force it to use any? which will use our patched find_target. CollectionProxy undefines define_singleton_method
        # (along with most instance methods) so we need to use #proxy_extend and a module to inject this
        # behavior.
        exists_module = Module.new do
          def exists?
            any?
          end
        end
        association.proxy.proxy_extend(exists_module)
      end
    end

    def load_association(record_registry, record, association_path)
      *record_path, association_name = *association_path
      records = record_registry.fetch(registry_key(record, record_path), []).select do |record|
        load_association?(record, association_name)
      end

      # TODO: Remove Me
      debug(association_path.size) { "Eager loading #{association_path} for #{record_string(records)}" }

      ActiveRecord::Associations::Preloader.new(records, [association_name]).run

      # TODO: Remove Me
      debug(association_path.size) do
        unloaded_records = records.select { |record| load_association?(record, association_name) }
        "Failed to eager load #{association_path} for #{record_string(unloaded_records)}" if unloaded_records.present?
      end

      # TODO: Remove Me
      debug(association_path.size) do
        loaded_records = records.reject { |record| load_association?(record, association_name) }
        "Done eager loading #{association_path} for #{record_string(loaded_records)}"
      end

      associated_records = records.map { |record| record.send(association_name) }.flatten.compact.uniq
      extend_associations(record_registry, associated_records, association_path)
    end

    # TODO: Remove me
    def debug(indent)
      if ENV.fetch('DEBUG_AUTO_EAGER_LOAD', 'false') == 'true'
        result = yield
        STDERR.puts "#{' ' * indent}#{result}" if result.present?
      end
    end

    # TODO: Remove me
    def record_string(records)
      records = Array.wrap(records)
      return "[]" unless records.present?

      records = records.sort_by(&:id)

      str = "#{records.first.class}("
      str << records.map { |record| "#{record.id}:#{record.object_id.to_s(16)}" }.join(", ")
      str << ")"
      str
    end

    def load_association?(record, association_name)
      # Need to make sure the record actually has the association which won't always
      # be the case in STI hierarchies e.g. only a subclass might have the association
      record.class.reflect_on_association(association_name).present? &&
        !record.association(association_name).loaded?
    end

    def registry_key(record, association_path)
      [record.class.base_class, association_path]
    end

    def collection_association_classes
      [ActiveRecord::Associations::Builder::CollectionAssociation] +
        ActiveRecord::Associations::Builder::CollectionAssociation.descendants
    end
  end
end
