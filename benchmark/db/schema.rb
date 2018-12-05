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
end

class Blog < ActiveRecord::Base
  has_many :posts
end

class Post < ActiveRecord::Base
  belongs_to :blog
  belongs_to :author, class_name: 'User'
end

class User < ActiveRecord::Base
  has_many :posts, foreign_key: :author_id
end
