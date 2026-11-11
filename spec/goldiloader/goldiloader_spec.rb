# frozen_string_literal: true

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
    ActiveRecord::Base.logger.info('Test setup complete')
  end

  after do
    # Always reset enablement status to a known-good state
    Goldiloader.globally_enabled = true
    Goldiloader.enabled = nil
  end

  it "auto eager loads has_many associations" do
    blogs = Blog.order(:name).to_a

    # Sanity check that associations aren't loaded yet
    blogs.each do |blog|
      expect(blog.association(:posts)).not_to be_loaded
    end

    expect do
      # Force the first blogs first post to load
      blogs.first.posts.to_a

      blogs.each do |blog|
        expect(blog.association(:posts)).to be_loaded
      end

      expect(blogs.first.posts.map(&:title)).to match_array(['blog1-post1', 'blog1-post2'])
      expect(blogs.second.posts.map(&:title)).to match_array(['blog2-post1', 'blog2-post2'])
    end.to execute_queries(Post => 1)
  end

  it "auto eager loads associations of models loaded with load_async" do
    blogs = Blog.order(:name).load_async
    expect(blogs).to be_scheduled
    blogs.to_a

    expect do
      blogs.first.posts.to_a

      blogs.each do |blog|
        expect(blog.association(:posts)).to be_loaded
      end
    end.to execute_queries(Post => 1)
  end

  it "auto eager loads associations of models loaded with find_by_sql" do
    blogs = Blog.find_by_sql('SELECT * FROM blogs ORDER BY name')

    expect do
      blogs.first.posts.to_a

      blogs.each do |blog|
        expect(blog.association(:posts)).to be_loaded
      end
    end.to execute_queries(Post => 1)
  end

  it "auto eager loads associations of models loaded with async_find_by_sql" do
    blogs = Blog.async_find_by_sql('SELECT * FROM blogs ORDER BY name').value

    expect do
      blogs.first.posts.to_a

      blogs.each do |blog|
        expect(blog.association(:posts)).to be_loaded
      end
    end.to execute_queries(Post => 1)
  end

  it "doesn't auto eager load associations of models loaded with find_by_sql and auto_include: false" do
    blogs = Blog.find_by_sql('SELECT * FROM blogs ORDER BY name', auto_include: false)

    expect do
      blogs.first.posts.to_a

      expect(blogs.last.association(:posts)).not_to be_loaded
    end.to execute_queries(Post => 1)
  end

  it "doesn't auto eager load associations of models loaded with async_find_by_sql and auto_include: false" do
    blogs = Blog.async_find_by_sql('SELECT * FROM blogs ORDER BY name', auto_include: false).value

    expect do
      blogs.first.posts.to_a

      expect(blogs.last.association(:posts)).not_to be_loaded
    end.to execute_queries(Post => 1)
  end

  it "ignores the auto_include value of the current scope in find_by_sql, as Rails ignores the current scope there" do
    blogs = Blog.auto_include(false).find_by_sql('SELECT * FROM blogs ORDER BY name')

    expect do
      blogs.first.posts.to_a

      expect(blogs.last.association(:posts)).to be_loaded
    end.to execute_queries(Post => 1)
  end

  it "shares one context between models loaded through an association while goldiloader is disabled" do
    posts = Goldiloader.disabled { Blog.order(:name).first.posts.to_a }

    expect do
      posts.first.author

      posts.each do |post|
        expect(post.association(:author)).to be_loaded
      end
    end.to execute_queries(User => 1)
  end

  it "auto eager loads associations of models loaded through an association with in-memory changes" do
    blog = Blog.order(:name).first
    blog.posts.build
    posts = blog.posts.to_a.select(&:persisted?)

    expect do
      posts.first.author

      posts.each do |post|
        expect(post.association(:author)).to be_loaded
      end
    end.to execute_queries(User => 1)
  end

  it "auto eager loads belongs_to associations" do
    posts = Post.order(:title).to_a

    # Sanity check that associations aren't loaded yet
    posts.each do |blog|
      expect(blog.association(:blog)).not_to be_loaded
    end

    expect do
      # Force the first post's blog to load
      posts.first.blog

      posts.each do |blog|
        expect(blog.association(:blog)).to be_loaded
      end

      expect(posts.map(&:blog).map(&:name)).to eq(['blog1', 'blog1', 'blog2', 'blog2'])
    end.to execute_queries(Blog => 1)
  end

  it "auto eager loads has_one associations" do
    users = User.order(:name).to_a

    # Sanity check that associations aren't loaded yet
    users.each do |user|
      expect(user.association(:address)).not_to be_loaded
    end

    expect do
      # Force the first user's address to load
      users.first.address

      users.each do |blog|
        expect(blog.association(:address)).to be_loaded
      end

      expect(users.map(&:address).map(&:city)).to match_array(['author1-city', 'author2-city', 'author3-city'])
    end.to execute_queries(Address => 1)
  end

  it "auto eager loads nested associations" do
    blogs = Blog.order(:name).to_a

    expect do
      blogs.first.posts.to_a.first.author

      blogs.flat_map(&:posts).each do |blog|
        expect(blog.association(:author)).to be_loaded
      end

      expect(blogs.first.posts.first.author).to eq author1
      expect(blogs.first.posts.second.author).to eq author2
      expect(blogs.second.posts.first.author).to eq author3
      expect(blogs.second.posts.second.author).to eq author1
    end.to execute_queries(Post => 1, User => 1)
  end

  it "auto eager loads has_many through associations" do
    blogs = Blog.order(:name).to_a

    expect do
      blogs.first.authors.to_a

      blogs.each do |blog|
        expect(blog.association(:authors)).to be_loaded
      end

      expect(blogs.first.authors).to match_array([author1, author2])
      expect(blogs.second.authors).to match_array([author3, author1])
    end.to execute_queries(Post => 1, User => 1)
  end

  it "auto eager loads nested has_many through associations" do
    blogs = Blog.order(:name).to_a

    expect do
      blogs.first.addresses.to_a

      blogs.each do |blog|
        expect(blog.association(:addresses)).to be_loaded
      end

      expect(blogs.first.addresses).to match_array([author1, author2].map(&:address))
      expect(blogs.second.addresses).to match_array([author3, author1].map(&:address))
    end.to execute_queries(Post => 1, User => 1, Address => 1)
  end

  it "auto eager loads associations when the model is loaded via find" do
    blog = Blog.find(blog1.id)
    blog.posts.to_a.first.author

    blog.posts.each do |post|
      expect(post.association(:author)).to be_loaded
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
    users = tags.map(&:owner).select { |owner| owner.is_a?(User) }.sort_by(&:name)
    users.first.posts.to_a

    users.each do |user|
      expect(user.association(:posts)).to be_loaded
    end

    expect(users.first.posts).to eq Post.where(author_id: author1.id)
    expect(users.second.posts).to eq Post.where(author_id: author2.id)
  end

  it "auto eager loads polymorphic associations with scopes" do
    hidden_user = User.create!(name: 'oddball')
    Tag.where(owner: group1).update_all(owner_type: 'User', owner_id: hidden_user.id)
    tags = Tag.where('parent_id IS NOT NULL').order(:name).to_a
    tags.first.scoped_owner

    tags.each do |tag|
      expect(tag.association(:scoped_owner)).to be_loaded
    end

    expect(tags.first.scoped_owner).to eq author1
    expect(tags.second.scoped_owner).to be_nil
    expect(tags.third.scoped_owner).to eq author2
  end

  it "sets inverse associations properly" do
    blogs = Blog.order(:name).to_a

    # Force the first blog's posts to load
    blogs.first.posts_with_inverse_of.to_a

    blogs.each do |blog|
      expect(blog.association(:posts_with_inverse_of)).to be_loaded
      blog.posts_with_inverse_of.each do |post|
        expect(post.association(:blog)).to be_loaded
        expect(post.blog.object_id).to eq(blog.object_id)
      end
    end
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
      expect(tag.association(:owner)).not_to be_loaded
    end
  end

  it "auto eager loads associations that have been overridden" do
    blogs = Blog.order(:name).to_a

    blogs.first.association(:posts_overridden).load_target

    blogs.each do |blog|
      expect(blog.association(:posts_overridden)).to be_loaded
    end
  end

  it "marks auto eager loaded models as read only when the association is read only" do
    blog = Blog.first!
    post = blog.read_only_posts.to_a.first
    expect { post.save! }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "doesn't mark auto eager loaded models as read only when the association is not read only" do
    blog = Blog.first!
    post = blog.posts.to_a.first
    expect { post.save! }.not_to raise_error
  end

  context "with manual eager loading" do
    let(:blog_scope) { Blog.order(:name) }

    shared_examples "it auto-eager loads associations of manually eager loaded associations" do
      specify do
        blogs = blog_scope.send(load_method, :posts).to_a

        expect do
          blogs.first.posts.to_a.first.author

          blogs.flat_map(&:posts).drop(1).each do |blog|
            expect(blog.association(:author)).to be_loaded
          end

          expect(blogs.first.posts.first.author).to eq author1
          expect(blogs.first.posts.second.author).to eq author2
          expect(blogs.second.posts.first.author).to eq author3
          expect(blogs.second.posts.second.author).to eq author1
        end.to execute_queries(User => 1)
      end
    end

    context "via includes" do
      let(:load_method) { :includes }

      it_behaves_like "it auto-eager loads associations of manually eager loaded associations"
    end

    context "via includes joined by references" do
      let(:load_method) { :includes }
      let(:blog_scope) { Blog.order(:name).references(:posts) }

      it_behaves_like "it auto-eager loads associations of manually eager loaded associations"
    end

    context "via eager_load" do
      let(:load_method) { :eager_load }

      it_behaves_like "it auto-eager loads associations of manually eager loaded associations"
    end

    context "via preload" do
      let(:load_method) { :preload }

      it_behaves_like "it auto-eager loads associations of manually eager loaded associations"
    end
  end

  context "with associations that can't be eager loaded" do
    let(:blogs) { Blog.order(:name).to_a }

    before do
      blog1.posts.create!(title: 'blog1-post3', author: author1)
      blog2.posts.create!(title: 'blog2-post3', author: author1)
    end

    shared_examples "it doesn't auto eager load the association" do |association_name|
      specify do
        blogs.drop(1).each do |blog|
          expect(blog.association(association_name)).not_to be_loaded
        end
      end
    end

    shared_examples "it auto eager loads the association" do |association_name|
      specify do
        blogs.drop(1).each do |blog|
          expect(blog.association(association_name)).to be_loaded
        end
      end
    end

    context "associations with a limit" do
      before do
        blogs.first.limited_posts.to_a
      end

      it "applies the limit correctly" do
        expect(blogs.first.limited_posts.to_a.size).to eq 2
      end

      it_behaves_like "it doesn't auto eager load the association", :limited_posts
    end

    context "associations with a group" do
      before do
        blogs.first.grouped_posts.to_a
      end

      it "applies the group correctly" do
        expect(blogs.first.grouped_posts.to_a.size).to eq 1
      end

      it_behaves_like "it auto eager loads the association", :grouped_posts
    end

    context "associations with an offset" do
      before do
        blogs.first.offset_posts.to_a
      end

      it "applies the offset correctly" do
        expect(blogs.first.offset_posts.to_a.size).to eq 1
      end

      it_behaves_like "it doesn't auto eager load the association", :offset_posts
    end

    context "associations with an overridden from" do
      before do
        blogs.first.from_posts.to_a
      end

      it "applies the from correctly" do
        expect(blogs.first.from_posts.to_a.size).to eq 1
      end

      it_behaves_like "it auto eager loads the association", :from_posts
    end

    context "associations with a join" do
      before do
        blogs.first.posts_ordered_by_author.to_a
      end

      it "applies the join correctly" do
        sorted_post_authors = blogs.first.posts.map(&:author).map(&:name).sort
        expect(blogs.first.posts_ordered_by_author.map(&:author).map(&:name)).to eq sorted_post_authors
      end

      it_behaves_like "it auto eager loads the association", :posts_ordered_by_author
    end

    context "associations with a join in a has_many_through" do
      before do
        blogs.first.authors_with_join.to_a
      end

      it "applies the join correctly" do
        sorted_post_cities = blogs.first.posts.map(&:author).map(&:address).map(&:city).sort
        expect(blogs.first.posts_ordered_by_author.map(&:author).map(&:address).map(&:city)).to eq sorted_post_cities
      end

      it_behaves_like "it auto eager loads the association", :authors_with_join
    end

    context "associations with an unscoped" do
      let(:authors) { User.order(:id).to_a }

      before do
        author1.address.update!(city: 'Boston')
        author2.address.update!(city: 'Philadelphia')
        author3.address.update!(city: 'Philadelphia')
        authors.first.scoped_address_with_default_scope_remove
      end

      it "applies the unscope correctly" do
        expect(authors.first.scoped_address_with_default_scope_remove).to be_present
      end

      it "auto eager loads the association" do
        authors.drop(1).each do |author|
          expect(author.association(:scoped_address_with_default_scope_remove)).to be_loaded
        end
      end
    end

    context "associations with an instance dependent scope" do
      before do
        blogs.first.instance_dependent_posts.to_a
      end

      it "applies the scope correctly" do
        expect(blogs.first.instance_dependent_posts.to_a).to match_array(blogs.first.posts)
      end

      it_behaves_like "it doesn't auto eager load the association", :instance_dependent_posts
    end

    context "has_one associations with an order" do
      before do
        blogs.first.post_with_order
      end

      it "applies the scope correctly" do
        expect(blogs.first.post_with_order).to eq(blogs.first.posts.order(:id).first)
      end

      it_behaves_like "it doesn't auto eager load the association", :post_with_order
    end
  end

  context "associations with a uniq" do
    let!(:post1) do
      Post.create! { |post| post.tags << child_tag1 << child_tag1 << child_tag3 }
    end

    let!(:post2) do
      Post.create! { |post| post.tags << child_tag1 << child_tag1 << child_tag2 }
    end

    let(:posts) { Post.where(id: [post1.id, post2.id]).order(:id).to_a }

    before do
      posts.first.unique_tags.to_a
    end

    it "applies the uniq correctly" do
      expect(posts.first.unique_tags.to_a).to match_array([child_tag1, child_tag3])
    end

    it "auto eager loads the association" do
      posts.each do |blog|
        expect(blog.association(:unique_tags)).to be_loaded
      end
    end
  end

  context "polymorphic associations with nil" do
    let!(:user) { User.create! }
    let!(:group) { Group.create! }

    let!(:post1) do
      Post.create! { |post| post.owner = user }
    end

    let!(:post2) do
      Post.create! { |post| post.owner = group }
    end

    let!(:post3) do
      Post.create!
    end

    let(:posts) { Post.where(id: [post1, post2, post3].map(&:id)).order(:id).to_a }

    before do
      posts.first.owner
    end

    it "loads the association correctly" do
      expect(posts.map(&:owner)).to eq [user, group, nil]
    end

    it "auto eager loads the association" do
      posts.select(&:owner_id).each do |post|
        expect(post.association(:owner)).to be_loaded
      end
    end
  end

  context "when a model is destroyed" do
    let!(:posts) { Post.where(blog_id: blog1.id).to_a }
    let(:destroyed_post) { posts.first }
    let(:other_post) { posts.last }

    before do
      blog_after_destroy = nil
      destroyed_post.define_singleton_method(:after_post_destroy) do
        blog_after_destroy = self.blog
      end
      destroyed_post.destroy
      @blog_after_destroy = blog_after_destroy
    end

    it "can load associations in after_destroy callbacks" do
      expect(@blog_after_destroy).to eq blog1
    end

    it "auto eager loads the associations on other models" do
      expect(other_post.association(:blog)).to be_loaded
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
      expect(other_blog.association(:posts)).not_to be_loaded
    end

    it "returns the correct models for the modified has_many association when accessing a peer" do
      other_blog.posts.to_a
      expect(blog.posts).to match_array Post.where(blog_id: blog.id)
    end
  end

  context "when the 'middle' part of a has_many through association was already loaded to memory and not modified" do
    let!(:posts) { Post.order(:title).to_a }
    let(:post) { posts.first }
    let(:other_post) { posts.last }

    before do
      post.post_tags.to_a
    end

    it "auto eager loads the association when accessing a peer" do
      other_post.tags.to_a
      expect(post.association(:tags)).to be_loaded
    end

    it "doesn't reload the already loaded models when accessing a peer" do
      object_ids = post.post_tags.map(&:object_id)
      other_post.tags.to_a
      expect(post.post_tags.map(&:object_id)).to eq(object_ids)
    end
  end

  context "when the 'middle' part of a has_many through association was already loaded to memory and modified" do
    let!(:posts) { Post.order(:title).to_a }
    let(:post) { posts.first }
    let(:other_post) { posts.last }

    before do
      post.post_tags.to_a.first.tag = child_tag3
    end

    it "doesn't auto eager loads the association when accessing a peer" do
      other_post.tags.to_a
      expect(post.association(:tags)).not_to be_loaded
    end

    it "doesn't reload the already loaded models when accessing a peer" do
      object_ids = post.post_tags.map(&:object_id)
      other_post.tags.to_a
      expect(post.post_tags.map(&:object_id)).to eq(object_ids)
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
      expect(other_post.association(:tags)).not_to be_loaded
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
        expect(blog.association(:posts)).not_to be_loaded
      end
    end

    it "doesn't auto eager loads a has_many association when exists? is called" do
      blogs = Blog.order(:name).to_a
      blogs.first.posts.exists?

      blogs.each do |blog|
        expect(blog.association(:posts)).not_to be_loaded
      end
    end

    it "doesn't auto eager loads a has_many association when last is called" do
      blogs = Blog.order(:name).to_a
      blogs.first.posts.last

      blogs.each do |blog|
        expect(blog.association(:posts)).not_to be_loaded
      end
    end

    it "doesn't auto eager loads a has_many association when ids is called" do
      blogs = Blog.order(:name).to_a
      blogs.first.post_ids

      blogs.each do |blog|
        expect(blog.association(:posts)).not_to be_loaded
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

    it "doesn't auto eager load a has_many association when exists? is called with arguments" do
      blogs = Blog.order(:name).to_a
      blogs.first.posts_fully_load.exists?(false)

      blogs.each do |blog|
        expect(blog.association(:posts_fully_load)).not_to be_loaded
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

    it "doesn't auto eager load associations when the query disables auto include" do
      blogs = Blog.auto_include(false).order(:name).to_a

      # Force the first blogs first post to load
      posts = blogs.first.posts.to_a
      expect(posts).to match_array Post.where(blog_id: blogs.first.id)

      blogs.drop(1).each do |blog|
        expect(blog.association(:posts)).not_to be_loaded
      end
    end

    it "doesn't auto eager load has_many associations with auto include disabled" do
      blogs = Blog.order(:name).to_a

      # Force the first blogs first post to load
      posts = blogs.first.posts_without_auto_include.to_a
      expect(posts).to match_array Post.where(blog_id: blogs.first.id)

      blogs.drop(1).each do |blog|
        expect(blog.association(:posts_without_auto_include)).not_to be_loaded
      end
    end

    it "doesn't auto eager load has_one associations with auto include disabled" do
      users = User.order(:name).to_a

      # Force the first user's address to load
      user = users.first
      address = user.address_without_auto_include
      expect(address).to eq Address.where(user_id: user.id).first

      users.drop(1).each do |blog|
        expect(blog.association(:address_without_auto_include)).not_to be_loaded
      end
    end

    it "doesn't auto eager load belongs_to associations with auto include disabled" do
      posts = Post.order(:title).to_a
      # Force the first post's blog to load
      post1 = posts.first
      blog = post1.blog_without_auto_include
      expect(blog).to eq Blog.where(id: post1.blog_id).first

      posts.drop(1).each do |post|
        expect(post.association(:blog_without_auto_include)).not_to be_loaded
      end
    end

    it "doesn't auto eager load has_and_belongs_to_many associations with auto include disabled" do
      posts = Post.all.to_a

      # Force the first post's tags to load
      posts.first.tags_without_auto_include.to_a

      posts.drop(1).each do |post|
        expect(post.association(:tags_without_auto_include)).not_to be_loaded
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
        expect(post.association(:tags)).not_to be_loaded
      end
    end
  end

  context "with auto_loading disabled by default" do
    before do
      Goldiloader.enabled = false
    end

    it "doesn't auto eager load has_many associations" do
      blogs = Blog.order(:name).to_a

      # Force the first blogs first post to load
      posts = blogs.first.posts.to_a
      expect(posts).to match_array Post.where(blog_id: blogs.first.id)

      blogs.drop(1).each do |blog|
        expect(blog.association(:posts)).not_to be_loaded
      end
    end

    it "doesn't auto eager load has_one associations" do
      users = User.order(:name).to_a

      # Force the first user's address to load
      user = users.first
      address = user.address
      expect(address).to eq Address.where(user_id: user.id).first

      users.drop(1).each do |blog|
        expect(blog.association(:address)).not_to be_loaded
      end
    end

    it "doesn't auto eager load belongs_to associations" do
      posts = Post.order(:title).to_a
      # Force the first post's blog to load
      post1 = posts.first
      blog = post1.blog
      expect(blog).to eq Blog.where(id: post1.blog_id).first

      posts.drop(1).each do |post|
        expect(post.association(:blog)).not_to be_loaded
      end
    end

    it "doesn't auto eager load has_and_belongs_to_many associations" do
      posts = Post.all.to_a

      # Force the first post's tags to load
      posts.first.tags.to_a

      posts.drop(1).each do |post|
        expect(post.association(:tags)).not_to be_loaded
      end
    end

    it "doesn't auto eager loads nested associations" do
      posts = Post.order(:title).to_a
      # Force the first post's blog to load
      blog = posts.first.blog

      # Load another blogs posts
      other_blog = posts.last.blog
      other_blog_post = other_blog.posts.to_a.first

      blog.posts.to_a.first.tags.to_a

      expect(other_blog_post.association(:tags)).not_to be_loaded

      other_blog.posts.each do |post|
        expect(post.association(:tags)).not_to be_loaded
      end
    end

    context "using enabled block" do
      shared_examples "it auto eager loads association" do |subject, association|
        specify do
          Goldiloader.enabled do
            items = send(subject)
            # Sanity check that associations aren't loaded yet
            items.each do |item|
              expect(item.association(association)).not_to be_loaded
            end

            relation = items.first.association(association)
            queries = { relation.klass => 1 }

            if relation.options[:through]
              through = items.first.association(relation.options[:through])
              queries[through.klass] = 1
            end

            expect do
              # Force load via auto include
              rel = items.to_a.first.association(association)
              # handle single and multi relations
              rel.load_target

              # Check that associations are loaded
              items.each do |blog|
                expect(blog.association(association)).to be_loaded
              end
            end.to execute_queries(queries)
          end
        end
      end

      let(:blogs) { Blog.order(:name).to_a }
      let(:posts) { Post.order(:title).to_a }
      let(:users) { User.order(:name).to_a }
      let(:posts_through_blogs) { blogs.flat_map(&:posts) }
      let(:tags) { Tag.where('parent_id IS NOT NULL').order(:name).to_a }
      let(:users_through_tags) { tags.map(&:owner).select { |o| o.is_a?(User) } }

      it_behaves_like "it auto eager loads association", :blogs, :posts
      it_behaves_like "it auto eager loads association", :blogs, :authors
      it_behaves_like "it auto eager loads association", :blogs, :posts_overridden
      it_behaves_like "it auto eager loads association", :posts, :blog
      it_behaves_like "it auto eager loads association", :users, :address
      it_behaves_like "it auto eager loads association", :posts_through_blogs, :author
      it_behaves_like "it auto eager loads association", :tags, :parent
      it_behaves_like "it auto eager loads association", :users_through_tags, :posts

      it "auto eager loads associations when the model is loaded via find" do
        Goldiloader.enabled do
          blog = Blog.find(blog1.id)

          blog.posts.to_a.first.author
          blog.posts.each do |post|
            expect(post.association(:author)).to be_loaded
          end
        end
      end

      it "doesn't auto eager loads associations outside the block" do
        blog = nil
        Goldiloader.enabled do
          blog = Blog.find(blog1.id)
        end

        arr = blog.posts.to_a
        arr.first.author
        arr.drop(1).each do |post|
          expect(post.association(:author)).not_to be_loaded
        end
      end
    end
  end

  context "using disabled block" do
    shared_examples "it does not auto eager loads association" do |subject, association|
      specify do
        Goldiloader.disabled do
          items = send(subject)
          # Sanity check that associations aren't loaded yet
          items.each do |item|
            expect(item.association(association)).not_to be_loaded
          end

          # Force load
          rel = items.to_a.first.association(association)
          # handle single and multi relations
          rel.load_target

          # Check that associations are loaded
          items.drop(1).each do |blog|
            expect(blog.association(association)).not_to be_loaded
          end
        end
      end
    end

    let(:blogs) { Blog.order(:name).to_a }
    let(:posts) { Post.order(:title).to_a }
    let(:users) { User.order(:name).to_a }
    let(:posts_through_blogs) { blogs.flat_map(&:posts) }
    let(:tags) { Tag.where('parent_id IS NOT NULL').order(:name).to_a }
    let(:users_through_tags) { tags.map(&:owner).select { |o| o.is_a?(User) } }

    it_behaves_like "it does not auto eager loads association", :blogs, :posts
    it_behaves_like "it does not auto eager loads association", :blogs, :authors
    it_behaves_like "it does not auto eager loads association", :blogs, :posts_overridden
    it_behaves_like "it does not auto eager loads association", :posts, :blog
    it_behaves_like "it does not auto eager loads association", :users, :address
    it_behaves_like "it does not auto eager loads association", :posts_through_blogs, :author
    it_behaves_like "it does not auto eager loads association", :tags, :parent
    it_behaves_like "it does not auto eager loads association", :users_through_tags, :posts

    it "does not auto eager loads associations when the model is loaded via find" do
      Goldiloader.disabled do
        blog = Blog.find(blog1.id)

        blog.posts.to_a.first.author
        blog.posts.drop(1).each do |post|
          expect(post.association(:author)).not_to be_loaded
        end
      end
    end

    it "does not auto eager loads associations for models outside the block" do
      blog = Blog.find(blog1.id)

      arr = blog.posts.to_a
      Goldiloader.disabled do
        arr.first.author
      end
      arr.drop(1).each do |post|
        expect(post.association(:author)).not_to be_loaded
      end
    end
  end

  context "custom preloads" do
    before do
      # create some additional records to make sure we actually have different counts
      blog1.posts.create!(title: 'another-post') do |post|
        post.tags << Tag.create!(name: 'some tag')
      end
    end

    let(:blogs) { Blog.order(:name).to_a }

    it "returns custom preloads" do
      expected_post_counts = blogs.map do |blog|
        blog.posts.count
      end

      expected_tag_counts = blogs.map do |blog|
        blog.posts.sum { |post| post.tags.count }
      end

      expect do
        expect(blogs.map(&:posts_count)).to eq expected_post_counts
        expect(blogs.map(&:tags_count)).to eq expected_tag_counts
      end.to execute_queries(Post => 1, Tag => 1)
    end

    it "works without a collection" do
      expect(blog1.posts_count).to eq blog1.posts.count
      expect(blog2.posts_count).to eq blog2.posts.count
    end

    it "prevents self references to the model inside the block" do
      expect do
        blog1.custom_preload_with_self_reference
      end.to raise_error(NoMethodError)
    end

    it "uses different caches for different blocks" do
      result1 = blog1.goldiload do |ids|
        ids.to_h { |id| [id, 42] }
      end
      expect(result1).to eq 42

      result2 = blog1.goldiload do |ids|
        ids.to_h { |id| [id, 666] }
      end
      expect(result2).to eq 666
    end

    it "can use an explicit cache_name" do
      # Define explicit cache key :random_cache_key
      blog1.goldiload(:random_cache_key) do |ids|
        ids.to_h { |id| [id, 42] }
      end

      # Another blog for the same key
      result = blog1.goldiload(:random_cache_key) do |ids|
        # :nocov:
        ids.to_h { |id| [id, 666] }
        # :nocov:
      end

      # First block should be used
      expect(result).to eq 42
    end

    it "can preload with a custom key" do
      posts = Post.all.order(id: :asc)
      expected_authors = posts.map(&:author)

      expect do
        expect(posts.map(&:author_via_global_id)).to eq expected_authors
      end.to execute_queries(User => 1)
    end

    it "can use an array as key argument" do
      yielded_values = nil
      result = blog1.goldiload(key: [:id, :name]) do |key_set|
        yielded_values = key_set
        key_set.to_h do |keys|
          [keys, 123]
        end
      end

      expect(yielded_values).to eq [
        [blog1.id, blog1.name]
      ]
      expect(result).to eq 123
    end
  end

  describe ".restore_auto_include" do
    around do |example|
      marshalling_format_version = ActiveRecord.marshalling_format_version
      ActiveRecord.marshalling_format_version = 7.1
      example.run
    ensure
      ActiveRecord.marshalling_format_version = marshalling_format_version
    end

    it "auto eager loads associations of models read back from a cache" do
      blogs = Goldiloader.restore_auto_include(read_back_from_cache(Blog.order(:name).to_a))

      expect do
        blogs.first.posts.to_a

        blogs.each do |blog|
          expect(blog.association(:posts)).to be_loaded
        end
      end.to execute_queries(Post => 1)
    end

    it "registers the models of associations loaded before caching" do
      blogs = Blog.order(:name).to_a
      blogs.first.posts.to_a
      blogs = Goldiloader.restore_auto_include(read_back_from_cache(blogs))
      posts = blogs.flat_map(&:posts)

      expect do
        posts.first.author

        posts.each do |post|
          expect(post.association(:author)).to be_loaded
        end
      end.to execute_queries(User => 1)
    end

    it "gives models the contexts of a regular load" do
      blogs = Blog.order(:name).to_a
      blogs.each do |blog|
        blog.posts.each { |post| post.tags.each(&:owner) }
        blog.read_only_posts.each(&:author)
        blog.posts_without_auto_include.each { |post| post.tags.each(&:owner) }
      end
      expected_contexts = auto_include_contexts(blogs)
      blogs = Goldiloader.restore_auto_include(read_back_from_cache(blogs))

      expect(auto_include_contexts(blogs)).to eq(expected_contexts)
    end

    it "gives targets of associations that can't be eager loaded the contexts of a regular load" do
      blogs = Blog.order(:name).to_a
      blogs.each do |blog|
        blog.limited_posts.to_a
        blog.instance_dependent_posts.to_a
        blog.post_with_order
      end
      expected_contexts = auto_include_contexts(blogs)
      blogs = Goldiloader.restore_auto_include(read_back_from_cache(blogs))

      expect(auto_include_contexts(blogs)).to eq(expected_contexts)
      expect(blogs.first.limited_posts.first.auto_include_context.size).to eq(2)
      expect(blogs.first.instance_dependent_posts.first.auto_include_context.size).to eq(2)
    end

    it "leaves models that weren't registered on purpose alone" do
      unregistered_models = [
        Blog.auto_include(false).order(:name).to_a,
        Blog.find_by_sql('SELECT * FROM blogs ORDER BY name', auto_include: false),
        [Blog.find(blog1.id), Blog.find(blog2.id)],
        Blog.order(:name).flat_map { |blog| blog.posts_without_auto_include.to_a }
      ]

      unregistered_models.each do |models|
        Goldiloader.restore_auto_include(models)

        models.each do |model|
          expect(model.auto_include_context.models).to eq([model])
        end
      end
    end

    it "restores models read back by the MessagePack cache serializer" do
      require 'active_support/message_pack'
      serializer = ActiveSupport::MessagePack::CacheSerializer
      blogs = Blog.order(:name).to_a
      blogs.each { |blog| blog.posts.to_a }
      blogs = Goldiloader.restore_auto_include(serializer.load(serializer.dump(blogs)))

      expect(blogs.first.auto_include_context.models).to eq(blogs)
      expect(blogs.first.posts.first.auto_include_context.models).to eq(blogs.flat_map(&:posts))
    end

    it "registers the models of each array or hash together and skips anything else" do
      blogs = [Blog.find(blog1.id), Blog.find(blog2.id)]
      cached = read_back_from_cache([*blogs, [User.find(author1.id)], { author: User.find(author2.id), count: 2 }, 'x'])

      expect(Goldiloader.restore_auto_include(cached)).to equal(cached)
      expect(cached.first.auto_include_context.models).to eq(cached.first(2))
      expect(cached.dig(2, 0).auto_include_context.models).to eq([cached.dig(2, 0)])
      expect(cached.dig(3, :author).auto_include_context.models).to eq([cached.dig(3, :author)])
    end

    it "registers separately cached lists of the same class separately" do
      cached = read_back_from_cache(featured: Post.order(:id).first(2), archive: Post.order(:id).last(2))
      Goldiloader.restore_auto_include(cached)

      expect(cached[:featured].first.auto_include_context.models).to eq(cached[:featured])
      expect(cached[:archive].first.auto_include_context.models).to eq(cached[:archive])
    end

    it "accepts cached data that holds itself" do
      hash = { blog: Blog.find(blog1.id) }
      hash[:self] = hash
      array = [Blog.find(blog2.id)]
      array << array
      hash, array = read_back_from_cache([hash, array])

      Goldiloader.restore_auto_include([hash, array])

      expect(hash[:blog].auto_include_context.models).to eq([hash[:blog]])
      expect(array.first.auto_include_context.models).to eq([array.first])
    end

    it "doesn't walk the associations of models that weren't read back from a cache" do
      blogs = Blog.order(:name).includes(:posts).to_a
      models = blogs + blogs.flat_map(&:posts)
      models.each { |model| allow(model).to receive(:association_cached?).and_call_original }

      Goldiloader.restore_auto_include(blogs)

      models.each { |model| expect(model).not_to have_received(:association_cached?) }
    end

    it "doesn't load a relation" do
      blogs = Blog.order(:name)

      expect do
        expect(Goldiloader.restore_auto_include(blogs)).to equal(blogs)
      end.to execute_queries({})
      expect(blogs).not_to be_loaded
    end

    it "doesn't register new records" do
      blog = Blog.new(name: 'new')
      2.times { |index| blog.posts.build(title: "new-#{index}") }
      blogs = Goldiloader.restore_auto_include(read_back_from_cache([blog, Blog.new]))

      expect(blogs.first.auto_include_context.models).to eq([blogs.first])
      expect(blogs.first.posts.first.auto_include_context.models).to eq([blogs.first.posts.first])
    end

    it "skips a polymorphic belongs_to with no target and a type that no longer exists" do
      post = Post.find(blog1.posts.first.id)
      post.update_columns(owner_type: 'User', owner_id: nil)
      post.reload.owner
      # As if the owner's class had been removed since the post was cached
      post.owner_type = 'RemovedOwner'
      posts = Goldiloader.restore_auto_include(read_back_from_cache([post]))

      expect(posts.first.auto_include_context.models).to eq(posts)
    end

    it "doesn't flag copies of models read back from a cache, nor reloaded models" do
      blog = read_back_from_cache(Blog.find(blog1.id))

      expect(blog.dup).not_to be_auto_include_context_lost
      expect(blog.clone).not_to be_auto_include_context_lost
      expect(blog.reload).not_to be_auto_include_context_lost
    end

    if Gem::Version.new(ActiveRecord::VERSION::STRING).release < Gem::Version.new('8.2')
      it "leaves models dumped in the 6.1 format, which keeps their context, alone" do
        ActiveRecord.marshalling_format_version = 6.1
        blogs = Blog.order(:name).to_a
        blogs.each { |blog| blog.posts.to_a }
        blogs = read_back_from_cache(blogs)
        context = blogs.first.auto_include_context

        Goldiloader.restore_auto_include(blogs)

        expect(blogs.first.auto_include_context).to equal(context)
        expect(context.models).to eq(blogs)
      end
    end

    it "keeps the contexts of models that weren't read back from a cache" do
      blogs = Blog.order(:name).includes(:posts).to_a
      blog_context = blogs.first.auto_include_context
      post_context = blogs.first.posts.first.auto_include_context

      expect(Goldiloader.restore_auto_include(blogs)).to equal(blogs)
      expect(blogs.first.auto_include_context).to equal(blog_context)
      expect(blogs.first.posts.first.auto_include_context).to equal(post_context)
    end

    it "registers models loaded back through an inverse association once" do
      blogs = Blog.order(:name).to_a
      blogs.each { |blog| blog.posts_with_inverse_of.to_a }
      blogs = Goldiloader.restore_auto_include(read_back_from_cache(blogs))

      expect(blogs.first.auto_include_context.models).to eq(blogs)
    end

    it "registers models of unrelated classes separately" do
      models = Goldiloader.restore_auto_include(read_back_from_cache(Blog.order(:name).to_a + User.order(:name).to_a))
      blogs, authors = models.partition { |model| model.is_a?(Blog) }

      expect(blogs.first.auto_include_context.models).to eq(blogs)
      expect(authors.first.auto_include_context.models).to eq(authors)
    end

    it "registers models of an STI hierarchy and their loaded associations together" do
      author2.update!(type: 'Admin')
      authors = User.order(:name).to_a
      authors.each { |author| author.posts.to_a }
      authors = Goldiloader.restore_auto_include(read_back_from_cache(authors))
      posts = authors.flat_map(&:posts)

      expect(authors.map(&:class)).to eq([User, Admin, User])
      expect(authors.first.auto_include_context.models).to eq(authors)
      expect(posts.first.auto_include_context.models).to eq(posts)
    end

    it "registers the loaded associations of a single model" do
      blog = Blog.order(:name).first
      blog.posts.to_a
      blog = Goldiloader.restore_auto_include(read_back_from_cache(blog))

      expect do
        blog.posts.first.author

        blog.posts.each do |post|
          expect(post.association(:author)).to be_loaded
        end
      end.to execute_queries(User => 1)
    end

    it "returns the models in their order, nil included" do
      blogs = Goldiloader.restore_auto_include(
        read_back_from_cache([Blog.find(blog2.id), nil, Blog.find(blog1.id)])
      )

      expect(blogs).to eq([blog2, nil, blog1])
      expect(blogs.first.auto_include_context.models).to eq(blogs.compact)
    end

    it "accepts nil" do
      expect(Goldiloader.restore_auto_include(nil)).to be_nil
    end

    it "accepts a loaded relation" do
      blogs = Blog.order(:name).load

      expect(Goldiloader.restore_auto_include(blogs)).to equal(blogs)
      expect(blogs.first.auto_include_context.models).to eq(blogs.to_a)
    end

    it "registers models of the same class loaded through different associations separately" do
      blog = Blog.find(blog2.id)
      blog.posts.to_a
      blog.read_only_posts.to_a
      blog = Goldiloader.restore_auto_include(read_back_from_cache(blog))

      expect(blog.posts.first.auto_include_context.models).to eq(blog.posts.to_a)
      expect(blog.read_only_posts.first.auto_include_context.models).to eq(blog.read_only_posts.to_a)
    end

    it "registers loaded polymorphic targets separately by class" do
      tags = Tag.order(:name).to_a
      tags.first.owner
      tags = Goldiloader.restore_auto_include(read_back_from_cache(tags))
      users, groups = tags.map(&:owner).uniq(&:object_id).partition { |owner| owner.is_a?(User) }

      expect(users.first.auto_include_context.models).to eq(users)
      expect(groups.first.auto_include_context.models).to eq(groups)
    end

    it "doesn't register loaded targets of associations with auto_include(false) together" do
      blogs = Blog.order(:name).to_a
      blogs.each { |blog| blog.posts_without_auto_include.to_a }
      blogs = Goldiloader.restore_auto_include(read_back_from_cache(blogs))
      post = blogs.first.posts_without_auto_include.first

      expect(post.auto_include_context.models).to eq([post])
    end

    it "registers the models below associations with auto_include(false)" do
      blogs = Blog.order(:name).to_a
      blogs.each { |blog| blog.posts_without_auto_include.each { |post| post.tags.to_a } }
      blogs = Goldiloader.restore_auto_include(read_back_from_cache(blogs))
      posts = blogs.flat_map(&:posts_without_auto_include)

      expect do
        posts.each { |post| post.tags.each(&:parent) }
      end.to execute_queries(Tag => posts.size)
    end

    def read_back_from_cache(models)
      Marshal.load(Marshal.dump(models))
    end

    # The context of each model in the loaded graph, as class and id pairs, in traversal order
    def auto_include_contexts(models, visited = Set.new.compare_by_identity)
      Array.wrap(models).flat_map do |model|
        next [] unless visited.add?(model)

        context = model.auto_include_context.models.map { |peer| [peer.class.name, peer.id] }
        loaded_targets = model.class.reflect_on_all_associations.filter_map do |reflection|
          model.association(reflection.name).target if model.association_cached?(reflection.name)
        end
        [[model.class.name, model.id, context]] + auto_include_contexts(loaded_targets.flatten.compact, visited)
      end
    end
  end

  describe "#globally_enabled" do
    context "enabled" do
      it "allows setting per thread" do
        Goldiloader.globally_enabled = true

        expect(Goldiloader.enabled?).to be true
        Goldiloader.enabled = false
        expect(Goldiloader.enabled?).to be false

        Thread.new { expect(Goldiloader.enabled?).to be true }.join
      end
    end

    context "disabled" do
      it "allows setting per thread" do
        Goldiloader.globally_enabled = false

        expect(Goldiloader.enabled?).to be false
        Goldiloader.enabled = true
        expect(Goldiloader.enabled?).to be true

        Thread.new { expect(Goldiloader.enabled?).to be false }.join
      end
    end

    it "doesn't persist the global value on the thread when using a block" do
      Thread.current[:goldiloader_enabled] = nil

      Goldiloader.globally_enabled = true
      Goldiloader.disabled do
        expect(Goldiloader.enabled?).to be false
      end
      expect(Goldiloader.enabled?).to be true
      expect(Thread.current[:goldiloader_enabled]).to eq nil

      Goldiloader.globally_enabled = false
      Goldiloader.enabled do
        expect(Goldiloader.enabled?).to be true
      end
      expect(Goldiloader.enabled?).to be false
      expect(Thread.current[:goldiloader_enabled]).to eq nil
    end
  end

  describe "CollectionProxy#exists?" do
    it "returns true for collections with values" do
      expect(parent_tag1.children).to exist
    end

    it "returns false for collections without values" do
      expect(child_tag1.children).not_to exist
    end

    it "returns false for new models with empty associations" do
      expect(Tag.new.children).not_to exist
    end
  end

  describe "active storage associations" do
    it "eager loads has_one_attached associations" do
      User.find_each do |user|
        create_attachment(owner: user, name: :avatar)
      end

      users = User.all.to_a
      users.first.avatar_blob
      users.each do |user|
        expect(user.association(:avatar_blob)).to be_loaded
      end
    end

    it "eager loads has_many_attached associations" do
      Post.find_each do |post|
        create_attachment(owner: post, name: :images)
        create_attachment(owner: post, name: :images)
      end

      posts = Post.all.to_a
      posts.first.images_blobs.to_a
      posts.each do |post|
        expect(post.association(:images_blobs)).to be_loaded
      end
    end

    # See https://github.com/salsify/goldiloader/issues/88
    it "doesn't block navigating from the attachment to the associated blob" do
      attachment = create_attachment(owner: User.first, name: :avatar)
      attachment_id = attachment.id
      blob_id = attachment.blob_id

      found_attachment = ActiveStorage::Attachment.find(attachment_id)
      expect(found_attachment.blob).to eq(ActiveStorage::Blob.find(blob_id))
    end

    def create_attachment(owner:, name:)
      key = SecureRandom.hex

      ActiveStorage::Blob.service.upload(key, StringIO.open('hello world'))

      blob = ActiveStorage::Blob.create!(
        key: key,
        filename: "#{owner.class}/#{owner.id}.file",
        byte_size: 128,
        checksum: 'abc',
        content_type: 'text'
      )

      ActiveStorage::Attachment.create!(
        name: name,
        record: owner,
        blob: blob
      )
    end
  end
end
