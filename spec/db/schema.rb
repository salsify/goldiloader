# frozen_string_literal: true

ActiveRecord::Schema.define(version: 0) do

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
  belongs_to :scoped_owner, -> { where("name like 'author%'") }, polymorphic: true,
             foreign_key: :owner_id, foreign_type: :owner_type
  has_many :post_tags
  has_many :posts, through: :post_tags
end

class PostTag < ActiveRecord::Base
  belongs_to :post
  belongs_to :tag
end

class Blog < ActiveRecord::Base
  has_many :posts
  has_many :posts_with_inverse_of, class_name: 'Post', inverse_of: :blog
  has_many :posts_without_auto_include, -> { auto_include(false) }, class_name: 'Post'
  has_many :posts_fully_load, fully_load: true, class_name: 'Post'

  has_many :read_only_posts, -> { readonly }, class_name: 'Post'
  has_many :limited_posts, -> { limit(2) }, class_name: 'Post'
  has_many :grouped_posts, -> { group(:blog_id) }, class_name: 'Post'
  has_many :offset_posts, -> { offset(2) }, class_name: 'Post'
  has_many :from_posts, -> { from('(select distinct blog_id from posts) as posts') }, class_name: 'Post'
  has_many :instance_dependent_posts, ->(instance) { Post.where(blog_id: instance.id) }, class_name: 'Post'

  has_many :posts_ordered_by_author, -> { joins(:author).order('users.name') }, class_name: 'Post'

  has_many :authors_with_join, -> { joins(:address).order('addresses.city') }, through: :posts, source: :author

  has_many :posts_overridden, class_name: 'Post'
  has_many :authors, through: :posts
  has_many :addresses, through: :authors

  has_one :post_with_order, -> { order(:id) }, class_name: 'Post'

  def posts_overridden
    'boom'
  end
end

class Post < ActiveRecord::Base
  belongs_to :blog
  belongs_to :blog_without_auto_include, -> { auto_include(false) }, class_name: 'Blog', foreign_key: :blog_id
  belongs_to :author, class_name: 'User'
  has_many :post_tags
  has_many :tags, through: :post_tags

  belongs_to :owner, polymorphic: true

  has_many :unique_tags, -> { distinct }, through: :post_tags, source: :tag, class_name: 'Tag'

  has_and_belongs_to_many :tags_without_auto_include, -> { auto_include(false) }, join_table: :post_tags,
                          class_name: 'Tag'

  after_destroy :after_post_destroy

  def after_post_destroy
    # Hook for tests
  end
end

class User < ActiveRecord::Base
  has_many :posts, foreign_key: :author_id
  has_many :tags, as: :owner
  has_one :address
  has_one :address_without_auto_include, -> { auto_include(false) }, class_name: 'Address'

  has_one :scoped_address_with_default_scope_remove, -> { unscope(where: :city) }, class_name: 'ScopedAddress'
end

class Address < ActiveRecord::Base
  belongs_to :user
end

class ScopedAddress < ActiveRecord::Base
  self.table_name = 'addresses'
  default_scope { where(city: ['Philadelphia']) }
  belongs_to :user
end

class Group < ActiveRecord::Base
  has_many :tags, as: :owner
end
