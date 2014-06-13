# encoding: UTF-8

ActiveRecord::Base.class_eval do
  attr_writer :auto_include_context

  def auto_include_context
    @auto_include_context ||= Goldiloader::AutoIncludeContext.create_empty
  end

end

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

Goldiloader::AssociationOptions.register

ActiveRecord::Associations::Association.class_eval do

  def auto_include?
    options.fetch(:auto_include) { default_auto_include }
  end

  def auto_include_context
    @auto_include_context ||= Goldiloader::AutoIncludeContext.new(owner.auto_include_context.model_registry,
                                                                  owner.auto_include_context.association_path + [reflection.name])
  end

  private

  def default_auto_include
    false
  end

  def load_with_auto_include(load_method, *args)
    unless loaded?
      if auto_include?
        Goldiloader::AssociationLoader.load(auto_include_context.model_registry, owner,
                                            auto_include_context.association_path)
      else
        send("#{load_method}_without_auto_include", *args)
      end
    end
    target
  end

end

ActiveRecord::Associations::SingularAssociation.class_eval do
  private

  def default_auto_include
    true
  end

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
      load_target if auto_include? && !loaded?
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

# The CollectionProxy just forwards exists? to the underlying scope so we need to intercept this and
# force it to use any? which will use our patched find_target. CollectionProxy undefines define_singleton_method
# (along with most instance methods) so we need to use #proxy_extend and a module to inject this
# behavior.
ActiveRecord::Associations::CollectionProxy.class_eval do
  def exists?
    size > 0
  end
end
