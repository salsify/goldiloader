# frozen_string_literal: true

require_relative 'performance_helper'

ForkingBenchmark.ips do |x|
  x.time = 5
  x.warmup = 2

  x.setup do
    setup_database

    # Setup data
    blog = Blog.create!
    user = User.create!
    Post.create!(author: user, blog: blog)
  end

  x.report("ActiveRecord: Single model's association") do
    Post.first!.author
  end

  x.report("Goldiloader: Single model's association", setup: -> { require('goldiloader') }) do |iterations|
    iterations.times do
      Post.first!.author
    end
  end

  x.compare!
end
