# encoding: UTF-8

module Goldiloader
  module ActiveRecordBasePatches
    extend ActiveSupport::Concern

    included do
      attr_writer :auto_include_context
    end

    def initialize_copy(other)
      super
      @auto_include_context = nil
    end

    def auto_include_context
      @auto_include_context ||= Goldiloader::AutoIncludeContext.create_empty.register_model(self)
    end
  end
end

ActiveRecord::Base.send(:include, Goldiloader::ActiveRecordBasePatches)

ActiveRecord::Relation.class_eval do

  def exec_queries_with_auto_include
    return exec_queries_without_auto_include if loaded?

    models = exec_queries_without_auto_include
    auto_include_context = Goldiloader::AutoIncludeContext.create_empty
    auto_include_context.register_models(models)
    models
  end

  alias_method_chain :exec_queries, :auto_include
end

ActiveRecord::Associations::Association.class_eval do

  class_attribute :default_auto_include, :default_auto_include_on_access
  self.default_auto_include = true
  self.default_auto_include_on_access = false

  def auto_include?
    # We only auto include associations that don't have in-memory changes since the
    # Rails association Preloader clobbers any in-memory changes
    target.blank? && !loaded? && options.fetch(:auto_include) { self.class.default_auto_include }
  end

  def auto_include_on_access?
    auto_include? && options.fetch(:auto_include_on_access) { self.class.default_auto_include_on_access }
  end

  def auto_include_context
    @auto_include_context ||= Goldiloader::AutoIncludeContext.new(owner.auto_include_context.model_registry,
                                                                  owner.auto_include_context.association_path + [reflection.name])
  end

  private

  def load_with_auto_include(load_method, *args)
    if loaded?
      target
    elsif auto_include?
      Goldiloader::AssociationLoader.load(auto_include_context.model_registry, owner,
                                          auto_include_context.association_path)
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
  # Force these methods to load the entire association for auto_included associations
  [:first, :second, :third, :forth, :fifth, :last, :size, :ids_reader, :empty?].each do |method|
    # Some of these methods were added in Rails 4
    next unless method_defined?(method)

    aliased_target, punctuation = method.to_s.sub(/([?!=])$/, ''), $1
    define_method("#{aliased_target}_with_auto_include#{punctuation}") do |*args, &block|
      load_target if auto_include_on_access? && !loaded?
      send("#{aliased_target}_without_auto_include#{punctuation}", *args, &block)
    end

    alias_method_chain method, :auto_include
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

# The CollectionProxy just forwards exists? to the underlying scope so we need to intercept this and
# force it to use any? which will use our patched find_target. CollectionProxy undefines define_singleton_method
# (along with most instance methods) so we need to use #proxy_extend and a module to inject this
# behavior.
ActiveRecord::Associations::CollectionProxy.class_eval do
  def exists?
    @association.auto_include_on_access? ? size > 0 : super
  end
end
