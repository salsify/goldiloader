# encoding: UTF-8

require 'spec_helper'

describe Goldiloader do
  let!(:author1) do
    User.create!(name: 'author1') { |u| u.address = Address.new(city: 'author1-city') }
  end

  let!(:author2) do
    User.create!(name: 'author2') { |u| u.address = Address.new(city: 'author2-city') }
  end

  let!(:author3) do
    User.create!(name: 'author3') { |u| u.address = Address.new(city: 'author3-city') }
  end

  let!(:group1) { Group.create!(name: 'group1') }

  let!(:parent_tag1) { Tag.create!(name: 'parent1') { |t| t.owner = group1 } }
  let!(:child_tag1) { parent_tag1.children.create!(name: 'parent1-child1') { |t| t.owner = author1 } }
  let!(:child_tag2) { parent_tag1.children.create!(name: 'parent1-child2') { |t| t.owner = group1 } }
  let!(:parent_tag2) { Tag.create!(name: 'parent2') { |t| t.owner = group1 } }
  let!(:child_tag3) { parent_tag2.children.create!(name: 'parent2-child1') { |t| t.owner = author2 } }

  let!(:blog1) do
    blog1 = Blog.create!(name: 'blog1')

    blog1.posts.create!(title: 'blog1-post1') do |post|
      post.author = author1
      post.tags << child_tag1 << child_tag2
    end

    blog1.posts.create!(title: 'blog1-post2') do |post|
      post.author = author2
      post.tags << child_tag1
    end

    blog1
  end

  let!(:blog2) do
    blog2 = Blog.create!(name: 'blog2')

    blog2.posts.create!(title: 'blog2-post1') do |post|
      post.author = author3
      post.tags << child_tag1
    end

    blog2.posts.create!(title: 'blog2-post2') do |post|
      post.author = author1
      post.tags << child_tag3
    end

    blog2
  end

  before do
    [Address, Blog, Post, Tag, User, Group].each do |klass|
      allow(klass).to receive(:find_by_sql).and_call_original
    end

    ActiveRecord::Base.logger.info('Test setup complete')
  end

  it "auto eager loads has_many associations" do
    blogs = Blog.order(:name).to_a

    # Sanity check that associations aren't loaded yet
    blogs.each do |blog|
      expect(blog.association(:posts)).to_not be_loaded
    end

    # Force the first blogs first post to load
    blogs.first.posts.to_a

    blogs.each do |blog|
      expect(blog.association(:posts)).to be_loaded
    end

    expect(blogs.first.posts.map(&:title)).to match_array(['blog1-post1', 'blog1-post2'])
    expect(blogs.second.posts.map(&:title)).to match_array(['blog2-post1', 'blog2-post2'])

    expect(Post).to have_received(:find_by_sql).once
  end

  it "auto eager loads belongs_to associations" do
    posts = Post.order(:title).to_a

    # Sanity check that associations aren't loaded yet
    posts.each do |blog|
      expect(blog.association(:blog)).to_not be_loaded
    end

    # Force the first post's blog to load
    posts.first.blog

    posts.each do |blog|
      expect(blog.association(:blog)).to be_loaded
    end

    expect(posts.map(&:blog).map(&:name)).to eq(['blog1', 'blog1', 'blog2', 'blog2'])
    expect(Blog).to have_received(:find_by_sql).once
  end

  it "auto eager loads has_one associations" do
    users = User.order(:name).to_a

    # Sanity check that associations aren't loaded yet
    users.each do |user|
      expect(user.association(:address)).to_not be_loaded
    end

    # Force the first user's address to load
    users.first.address

    users.each do |blog|
      expect(blog.association(:address)).to be_loaded
    end

    expect(users.map(&:address).map(&:city)).to match_array(['author1-city', 'author2-city', 'author3-city'])
    expect(Address).to have_received(:find_by_sql).once
  end

  it "auto eager loads nested associations" do
    blogs = Blog.order(:name).to_a
    blogs.first.posts.to_a.first.author

    blogs.flat_map(&:posts).each do |blog|
      expect(blog.association(:author)).to be_loaded
    end

    expect(blogs.first.posts.first.author).to eq author1
    expect(blogs.first.posts.second.author).to eq author2
    expect(blogs.second.posts.first.author).to eq author3
    expect(blogs.second.posts.second.author).to eq author1
    expect(Post).to have_received(:find_by_sql).once
  end

  it "auto eager loads has_many through associations" do
    blogs = Blog.order(:name).to_a
    blogs.first.authors.to_a

    blogs.each do |blog|
      expect(blog.association(:authors)).to be_loaded
    end

    expect(blogs.first.authors).to match_array([author1, author2])
    expect(blogs.second.authors).to match_array([author3, author1])
    expect(User).to have_received(:find_by_sql).once
  end

  it "auto eager loads associations when the model is loaded via find" do
    blog = Blog.find(blog1.id)
    blog.posts.to_a.first.author

    blog.posts.each do |blog|
      expect(blog.association(:author)).to be_loaded
    end
  end

  it "auto eager loads polymorphic associations" do
    tags = Tag.where('parent_id IS NOT NULL').order(:name).to_a
    tags.first.owner

    tags.each do |tag|
      expect(tag.association(:owner)).to be_loaded
    end

    expect(tags.first.owner).to eq author1
    expect(tags.second.owner).to eq group1
    expect(tags.third.owner).to eq author2
  end

  it "auto eager loads associations of polymorphic associations" do
    tags = Tag.where('parent_id IS NOT NULL').order(:name).to_a
    users = tags.map(&:owner).select {|owner| owner.is_a?(User) }.sort_by(&:name)
    users.first.posts.to_a

    users.each do |user|
      expect(user.association(:posts)).to be_loaded
    end

    expect(users.first.posts).to eq Post.where(author_id: author1.id)
    expect(users.second.posts).to eq Post.where(author_id: author2.id)
  end

  it "only auto eager loads associations loaded through the same path" do
    root_tags = Tag.where(parent_id: nil).order(:name).to_a
    root_tags.first.children.to_a

    # Make sure we loaded all child tags
    root_tags.each do |tag|
      expect(tag.association(:children)).to be_loaded
    end

    # Force a load of a root tag's owner
    root_tags.first.owner

    # All root tag owners should be loaded
    root_tags.each do |tag|
      expect(tag.association(:owner)).to be_loaded
    end

    # Child tag owners should not be loaded
    child_tags = root_tags.flat_map(&:children)
    child_tags.each do |tag|
      expect(tag.association(:owner)).to_not be_loaded
    end
  end

  context "when a has_many association has in-memory changes" do
    let!(:blogs) { Blog.order(:name).to_a }
    let(:blog) { blogs.first }
    let(:other_blog) { blogs.last }

    before do
      blog.posts.create(title: 'blog1-new-post')
    end

    it "returns the correct models for the modified has_many association" do
      expect(blog.posts).to match_array Post.where(blog_id: blog.id)
    end

    it "doesn't auto eager load peers when accessing the modified has_many association" do
      blog.posts.to_a
      expect(other_blog.association(:posts)).to_not be_loaded
    end

    it "returns the correct models for the modified has_many association when accessing a peer" do
      other_blog.posts.to_a
      expect(blog.posts).to match_array Post.where(blog_id: blog.id)
    end
  end

  context "when a has_many through association has in-memory changes" do
    let!(:posts) { Post.order(:title).to_a }
    let(:post) { posts.first }
    let(:other_post) { posts.last }

    before do
      tag = Tag.create(name: 'new-tag')
      post.post_tags.create(tag: tag)
    end

    it "returns the correct models for the modified has_many through association" do
      expect(post.tags).to match_array PostTag.where(post_id: post.id).includes(:tag).map(&:tag)
    end

    it "doesn't auto eager load peers when accessing the modified has_many through association" do
      post.tags.to_a
      expect(other_post.association(:tags)).to_not be_loaded
    end

    it "returns the correct models for the modified has_many through association when accessing a peer" do
      other_post.tags.to_a
      expect(post.tags).to match_array PostTag.where(post_id: post.id).includes(:tag).map(&:tag)
    end
  end

  context "with fully_load false" do

    it "doesn't auto eager loads a has_many association when size is called" do
      blogs = Blog.order(:name).to_a
      blogs.first.posts.size

      blogs.each do |blog|
        expect(blog.association(:posts)).to_not be_loaded
      end
    end

    it "doesn't auto eager loads a has_many association when exists? is called" do
      blogs = Blog.order(:name).to_a
      blogs.first.posts.exists?

      blogs.each do |blog|
        expect(blog.association(:posts)).to_not be_loaded
      end
    end

    it "doesn't auto eager loads a has_many association when last is called" do
      blogs = Blog.order(:name).to_a
      blogs.first.posts.last

      blogs.each do |blog|
        expect(blog.association(:posts)).to_not be_loaded
      end
    end

    it "doesn't auto eager loads a has_many association when ids is called" do
      blogs = Blog.order(:name).to_a
      blogs.first.post_ids

      blogs.each do |blog|
        expect(blog.association(:posts)).to_not be_loaded
      end
    end
  end

  context "with fully_load true" do

    it "auto eager loads a has_many association when size is called" do
      blogs = Blog.order(:name).to_a
      blogs.first.posts_fully_load.size

      blogs.each do |blog|
        expect(blog.association(:posts_fully_load)).to be_loaded
      end
    end

    it "auto eager loads a has_many association when exists? is called" do
      blogs = Blog.order(:name).to_a
      blogs.first.posts_fully_load.exists?

      blogs.each do |blog|
        expect(blog.association(:posts_fully_load)).to be_loaded
      end
    end

    it "auto eager loads a has_many association when last is called" do
      blogs = Blog.order(:name).to_a
      blogs.first.posts_fully_load.last

      blogs.each do |blog|
        expect(blog.association(:posts_fully_load)).to be_loaded
      end
    end

    it "auto eager loads a has_many association when ids is called" do
      blogs = Blog.order(:name).to_a
      blogs.first.posts_fully_load_ids

      blogs.each do |blog|
        expect(blog.association(:posts_fully_load)).to be_loaded
      end
    end

  end

  context "with auto_include disabled" do

    it "doesn't auto eager load has_many associations" do
      blogs = Blog.order(:name).to_a

      # Force the first blogs first post to load
      posts = blogs.first.posts_without_auto_include.to_a
      expect(posts).to match_array Post.where(blog_id: blogs.first.id)

      blogs.drop(1).each do |blog|
        expect(blog.association(:posts_without_auto_include)).to_not be_loaded
      end
    end

    it "doesn't auto eager load has_one associations" do
      users = User.order(:name).to_a

      # Force the first user's address to load
      user = users.first
      address = user.address_without_auto_include
      expect(address).to eq Address.where(user_id: user.id).first

      users.drop(1).each do |blog|
        expect(blog.association(:address_without_auto_include)).to_not be_loaded
      end
    end

    it "doesn't auto eager load belongs_to associations" do
      posts = Post.order(:title).to_a
      # Force the first post's blog to load
      post = posts.first
      blog = post.blog_without_auto_include
      expect(blog).to eq Blog.where(id: post.blog_id).first

      posts.drop(1).each do |blog|
        expect(blog.association(:blog_without_auto_include)).to_not be_loaded
      end
    end

    it "still auto eager loads nested associations" do
      posts = Post.order(:title).to_a
      # Force the first post's blog to load
      blog = posts.first.blog_without_auto_include

      # Load another blogs posts
      other_blog = posts.last.blog_without_auto_include
      other_blog.posts.to_a

      blog.posts.to_a.first.tags.to_a

      blog.posts.each do |post|
        expect(post.association(:tags)).to be_loaded
      end

      other_blog.posts.each do |post|
        expect(post.association(:tags)).to_not be_loaded
      end
    end
  end
end
