# frozen_string_literal: true

require 'spec_helper'

describe Goldiloader::Cache do
  let!(:author1) { User.create!(name: 'author1') }
  let!(:author2) { User.create!(name: 'author2') }

  let!(:blog1) do
    Blog.create!(name: 'blog1') do |blog|
      blog.posts.build(title: 'blog1-post1', author: author1)
      blog.posts.build(title: 'blog1-post2', author: author2)
    end
  end

  let!(:blog2) do
    Blog.create!(name: 'blog2') do |blog|
      blog.posts.build(title: 'blog2-post1', author: author2)
    end
  end

  let(:cache) { ActiveSupport::Cache::MemoryStore.new }

  around do |example|
    marshalling_format_version = ActiveRecord.marshalling_format_version
    ActiveRecord.marshalling_format_version = 7.1
    example.run
  ensure
    ActiveRecord.marshalling_format_version = marshalling_format_version
  end

  before do
    allow(Rails).to receive(:cache).and_return(cache)
  end

  it "auto eager loads associations of models read back on a cache hit" do
    Goldiloader::Cache.fetch('blogs') { Blog.order(:name).includes(:posts).to_a }
    blogs = Goldiloader::Cache.fetch('blogs') { raise 'cache miss' }
    posts = blogs.flat_map(&:posts)

    expect(blogs.first.auto_include_context.models).to eq(blogs)
    expect do
      posts.first.author

      posts.each do |post|
        expect(post.association(:author)).to be_loaded
      end
    end.to execute_queries(User => 1)
  end

  it "auto eager loads associations of a single model read back on a cache hit" do
    Goldiloader::Cache.fetch('blog') { Blog.includes(:posts).find(blog1.id) }
    blog = Goldiloader::Cache.fetch('blog') { raise 'cache miss' }

    expect(blog.posts.first.auto_include_context.models).to eq(blog.posts.to_a)
  end

  it "leaves the contexts of models loaded on a cache miss alone" do
    allow(Goldiloader).to receive(:reset_auto_include_context)

    blogs = Goldiloader::Cache.fetch('blogs') { Blog.order(:name).to_a }

    expect(blogs).to eq([blog1, blog2])
    expect(Goldiloader).not_to have_received(:reset_auto_include_context)
  end

  it "passes its options to Rails.cache" do
    allow(cache).to receive(:fetch).and_call_original

    Goldiloader::Cache.fetch('blogs', expires_in: 60) { Blog.order(:name).to_a }

    expect(cache).to have_received(:fetch).with('blogs', { expires_in: 60 })
  end

  it "accepts nil" do
    expect(Goldiloader::Cache.fetch('blog') { Blog.find_by(name: 'missing') }).to be_nil
    expect(Goldiloader::Cache.fetch('blog') { raise 'cache miss' }).to be_nil
  end

  it "accepts nil in an array" do
    Goldiloader::Cache.fetch('blogs') { [Blog.find(blog1.id), nil] }
    blogs = Goldiloader::Cache.fetch('blogs') { raise 'cache miss' }

    expect(blogs).to eq([blog1, nil])
  end

  it "raises for other values without caching them" do
    expect do
      Goldiloader::Cache.fetch('blogs') { { featured: Blog.order(:name).to_a } }
    end.to raise_error(ArgumentError, /not Hash/)
    expect(cache.exist?('blogs')).to be(false)
  end
end
