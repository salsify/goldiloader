# encoding: UTF-8

require 'spec_helper'

describe Goldiloader do

  before do
    blog1 = Blog.create!(name: 'blog1')
    blog1.posts.create!(title: 'blog1-post1')
    blog1.posts.create!(title: 'blog1-post2')

    blog2 = Blog.create!(name: 'blog2')
    blog2.posts.create!(title: 'blog2-post1')
    blog2.posts.create!(title: 'blog2-post2')
  end

  it "works" do
    Blog.all.to_a.each do |blog|
      blog.posts.to_a
    end
  end
end
