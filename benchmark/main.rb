# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

require 'benchmark/ips'

ENV['RAILS_ENV'] = 'test'

require 'active_record'

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: ':memory:'
)

require_relative './db/schema.rb'

# Setup data
blog_1 = Blog.create!
blog_2 = Blog.create!
100.times do
  user_1 = User.create!
  user_2 = User.create!
  Post.create!(author: user_1, blog: blog_1)
  Post.create!(author: user_2, blog: blog_2)
end

Benchmark.ips do |x|
  x.time = 5
  x.warmup = 2

  # Use AR's eager loading
  x.report('AR eager loading: ') do
    ::Blog.all.includes(posts: :author).each do |blog|
      blog.posts.each do |post|
        post.author.id
      end
    end
  end

  require 'goldiloader'

  # Use goldiloader
  x.report('AR with goldiloader: ') do
    ::Blog.all.each do |blog|
      blog.posts.each do |post|
        post.author.id
      end
    end
  end

  x.compare!
end
