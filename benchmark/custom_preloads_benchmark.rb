# frozen_string_literal: true

require_relative 'performance_helper'

ForkingBenchmark.ips do |x|
  x.setup do
    setup_database

    # Setup data
    100.times do
      blog = Blog.create!
      5.times do
        Post.create!(blog: blog)
      end
    end
  end

  x.report('ActiveRecord manual preloading') do
    blogs = ::Blog.all.to_a
    posts_counts = ::Post.where(blog_id: blogs.map(&:id)).group(:blog_id).count
    blogs.each do |blog|
      posts_counts[blog.id]
    end
  end

  goldiloader_setup = -> do
    require('goldiloader')

    # Define the custom preload once Goldiloader has been required since it depends on goldiload
    ::Blog.class_eval do
      def posts_count
        goldiload do |ids|
          ::Post.where(blog_id: ids).group(:blog_id).count
        end
      end

      def named_posts_count
        goldiload(:posts_count) do |ids|
          ::Post.where(blog_id: ids).group(:blog_id).count
        end
      end
    end
  end
  x.report('Goldiloader custom preloading', setup: goldiloader_setup) do
    ::Blog.all.each(&:posts_count)
  end

  x.report('Goldiloader custom preloading with explicit cache name', setup: goldiloader_setup) do
    ::Blog.all.each(&:named_posts_count)
  end

  x.compare!
end
