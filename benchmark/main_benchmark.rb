# frozen_string_literal: true

require_relative 'performance_helper'

ForkingBenchmark.ips do |x|
  x.setup do
    setup_database

    # Setup data
    blog_1 = Blog.create!
    blog_2 = Blog.create!
    100.times do
      user_1 = User.create!
      user_2 = User.create!
      Post.create!(author: user_1, blog: blog_1)
      Post.create!(author: user_2, blog: blog_2)
    end
  end

  x.report('ActiveRecord eager loading') do
    ::Blog.all.includes(posts: :author).each do |blog|
      blog.posts.each do |post|
        post.author.id
      end
    end
  end

  x.report('Goldiloader eager loading', setup: -> { require('goldiloader') }) do
    ::Blog.all.each do |blog|
      blog.posts.each do |post|
        post.author.id
      end
    end
  end

  x.compare!
end
