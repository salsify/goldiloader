# encoding: UTF-8

ActiveRecord::Schema.define(:version => 0) do

  create_table(:blogs, force: true) do |t|
    t.string :name
  end

  create_table(:posts, force: true) do |t|
    t.string :title
    t.integer :blog_id
    t.integer :author_id
    t.string :owner_type
    t.integer :owner_id
  end

  create_table(:users, force: true) do |t|
    t.string :name
  end

  create_table(:addresses, force: true) do |t|
    t.string :city
    t.integer :user_id
  end

  create_table(:groups, force: true) do |t|
    t.string :name
  end

  create_table(:tags, force: true) do |t|
    t.string :name
    t.integer :parent_id
    t.string :owner_type
    t.integer :owner_id
  end

  create_table(:post_tags, force: true) do |t|
    t.integer :post_id
    t.integer :tag_id
  end
end

class Tag < ActiveRecord::Base
  belongs_to :parent, class_name: 'Tag'
  has_many :children, class_name: 'Tag', foreign_key: :parent_id

  belongs_to :owner, polymorphic: true
  has_many :post_tags
  has_many :posts, through: :post_tags

  if Goldiloader::Compatibility.mass_assignment_security_enabled?
    attr_accessible :name
  end
end

class PostTag < ActiveRecord::Base
  belongs_to :post
  belongs_to :tag
end

class Blog < ActiveRecord::Base
  has_many :posts
  has_many :posts_without_auto_include, auto_include: false, class_name: 'Post'
  has_many :posts_fully_load, fully_load: true, class_name: 'Post'

  if ActiveRecord::VERSION::MAJOR >= 4
    has_many :read_only_posts, -> { readonly }, class_name: 'Post'
    has_many :limited_posts, -> { limit(2) }, class_name: 'Post'
    has_many :grouped_posts, -> { group(:blog_id) }, class_name: 'Post'
    has_many :offset_posts, -> { offset(2) }, class_name: 'Post'
    has_many :from_posts, -> { from('(select distinct blog_id from posts) as posts') }, class_name: 'Post'
    has_many :instance_dependent_posts, ->(instance) { Post.where(blog_id: instance.id) }, class_name: 'Post'

    has_many :posts_ordered_by_author, -> { joins(:author).order('users.name') }, class_name: 'Post'

    has_many :authors_with_join, -> { joins(:address).order('addresses.city') }, through: :posts, source: :author
  else
    has_many :read_only_posts, readonly: true, class_name: 'Post'
    has_many :limited_posts, limit: 2, class_name: 'Post'
    has_many :grouped_posts, group: :blog_id, class_name: 'Post'
    has_many :offset_posts, offset: 2, class_name: 'Post'

    has_many :posts_ordered_by_author, include: :author, order: 'users.name', class_name: 'Post'
  end

  if Goldiloader::Compatibility.association_finder_sql_enabled?
    has_many :finder_sql_posts, finder_sql: Proc.new { "select distinct blog_id from posts where blog_id = #{self.id}" },
             class_name: 'Post'
  end

  has_many :posts_overridden, class_name: 'Post'
  has_many :authors, through: :posts
  has_many :addresses, through: :authors

  if Goldiloader::Compatibility.mass_assignment_security_enabled?
    attr_accessible :name
  end

  def posts_overridden
    'boom'
  end
end

class Post < ActiveRecord::Base
  belongs_to :blog
  belongs_to :blog_without_auto_include, auto_include: false, class_name: 'Blog', foreign_key: :blog_id
  belongs_to :author, class_name: 'User'
  has_many :post_tags
  has_many :tags, through: :post_tags

  belongs_to :owner, polymorphic: true

  if ActiveRecord::VERSION::MAJOR >= 4
    has_many :unique_tags, -> { distinct }, through: :post_tags, source: :tag, class_name: 'Tag'
  else
    has_many :unique_tags, through: :post_tags, source: :tag, uniq: true, class_name: 'Tag'
  end

  if ActiveRecord::VERSION::MAJOR < 4
    has_and_belongs_to_many :unique_tags_has_and_belongs, join_table: :post_tags, class_name: 'Tag', uniq: true
  end

  after_destroy :after_post_destroy

  if Goldiloader::Compatibility.mass_assignment_security_enabled?
    attr_accessible :title
  end

  def after_post_destroy
    # Hook for tests
  end
end

class User < ActiveRecord::Base
  has_many :posts, foreign_key: :author_id
  has_many :tags, as: :owner
  has_one :address
  has_one :address_without_auto_include, auto_include: false, class_name: 'Address'

  if Goldiloader::Compatibility.unscope_query_method_enabled?
    has_one :scoped_address_with_default_scope_remove, -> { unscope(where: :city) }, class_name: 'ScopedAddress'
  end

  if Goldiloader::Compatibility.mass_assignment_security_enabled?
    attr_accessible :name
  end
end

class Address < ActiveRecord::Base
  belongs_to :user

  if Goldiloader::Compatibility.mass_assignment_security_enabled?
    attr_accessible :city
  end
end

class ScopedAddress < ActiveRecord::Base
  self.table_name = 'addresses'
  default_scope { where(city: ['Philadelphia'])}
  belongs_to :user

  if Goldiloader::Compatibility.mass_assignment_security_enabled?
    attr_accessible :city
  end
end

class Group < ActiveRecord::Base
  has_many :tags, as: :owner

  if Goldiloader::Compatibility.mass_assignment_security_enabled?
    attr_accessible :name
  end
end
