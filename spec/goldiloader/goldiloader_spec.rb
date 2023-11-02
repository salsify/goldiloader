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
    shared_examples "it auto-eager loads associations of manually eager loaded associations" do
      specify do
        blogs = Blog.order(:name).send(load_method, :posts).to_a

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
        blog.posts.sum {|post| post.tags.count }
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
