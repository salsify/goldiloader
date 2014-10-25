# encoding: UTF-8

module Goldiloader
  module AutoIncludableModel
    extend ActiveSupport::Concern

    included do
      attr_writer :auto_include_context
    end

    def initialize_copy(other)
      super
      @auto_include_context = nil
    end

    def auto_include_context
      @auto_include_context ||= Goldiloader::AutoIncludeContext.new.register_model(self)
    end

    def reload(*)
      @auto_include_context = nil
      super
    end
  end
end

ActiveRecord::Base.send(:include, Goldiloader::AutoIncludableModel)

ActiveRecord::Relation.class_eval do

  def exec_queries_with_auto_include
    return exec_queries_without_auto_include if loaded?

    models = exec_queries_without_auto_include
    Goldiloader::AutoIncludeContext.register_models(models, eager_load_values)
    models
  end

  alias_method_chain :exec_queries, :auto_include
end

ActiveRecord::Associations::Association.class_eval do

  class_attribute :default_auto_include, :default_fully_load
  self.default_auto_include = true
  self.default_fully_load = false

  def auto_include?
    # We only auto include associations that don't have in-memory changes since the
    # Rails association Preloader clobbers any in-memory changes
    !loaded? && target.blank? && options.fetch(:auto_include) { self.class.default_auto_include } && eager_loadable?
  end

  def fully_load?
    !loaded? && options.fetch(:fully_load) { self.class.default_fully_load }
  end

  private

  def eager_loadable?
    association_info = Goldiloader::AssociationInfo.new(self)
    !association_info.limit? &&
        !association_info.offset? &&
        !association_info.group? &&
        !association_info.from? &&
        !association_info.finder_sql? &&
        # Joins not properly eager loaded - See https://github.com/salsify/goldiloader/issues/11
        !association_info.joins? &&
        # Unscope not properly eager loaded - See https://github.com/salsify/goldiloader/issues/13
        !association_info.unscope? &&
        !association_info.instance_dependent?
  end

  def load_with_auto_include(load_method, *args)
    if loaded? && !stale_target?
      target
    elsif auto_include?
      Goldiloader::AssociationLoader.load(owner, reflection.name)
      target
    else
      send("#{load_method}_without_auto_include", *args)
    end
  end

end

ActiveRecord::Associations::SingularAssociation.class_eval do

  private

  def find_target_with_auto_include(*args)
    load_with_auto_include(:find_target, *args)
  end

  alias_method_chain :find_target, :auto_include
end

ActiveRecord::Associations::CollectionAssociation.class_eval do
  # Force these methods to load the entire association for fully_load associations
  [:first, :second, :third, :fourth, :fifth, :last, :size, :ids_reader, :empty?].each do |method|
    # Some of these methods were added in Rails 4
    next unless method_defined?(method)

    aliased_target, punctuation = method.to_s.sub(/([?!=])$/, ''), $1
    define_method("#{aliased_target}_with_fully_load#{punctuation}") do |*args, &block|
      load_target if fully_load?
      send("#{aliased_target}_without_fully_load#{punctuation}", *args, &block)
    end

    alias_method_chain method, :fully_load
  end

  private

  def load_target_with_auto_include(*args)
    load_with_auto_include(:load_target, *args)
  end

  alias_method_chain :load_target, :auto_include

end

[ActiveRecord::Associations::HasManyThroughAssociation, ActiveRecord::Associations::HasOneThroughAssociation].each do |klass|
  klass.class_eval do
    def auto_include?
      # Only auto include through associations if the target association is auto-loadable
      through_association = owner.association(through_reflection.name)
      through_association.auto_include? && super
    end
  end
end

# uniq in Rails 3 not properly eager loaded - See https://github.com/salsify/goldiloader/issues/16
if ActiveRecord::VERSION::MAJOR < 4
  ActiveRecord::Associations::HasAndBelongsToManyAssociation.class_eval do
    def eager_loadable?
      association_info = Goldiloader::AssociationInfo.new(self)
      super && !association_info.uniq?
    end
  end
end

# The CollectionProxy just forwards exists? to the underlying scope so we need to intercept this and
# force it to use size which handles fully_load properly.
ActiveRecord::Associations::CollectionProxy.class_eval do
  def exists?(*args)
    # We don't fully_load the association when arguments are passed to exists? since Rails always
    # pushes this query into the database without any caching (and it likely not a common
    # scenario worth optimizing).
    args.empty? && @association.fully_load? ? size > 0 : super
  end
end
