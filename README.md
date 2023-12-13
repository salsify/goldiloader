# Goldiloader

[![Gem Version](https://badge.fury.io/rb/goldiloader.svg)][gem]
[![Build Status](https://circleci.com/gh/salsify/goldiloader.svg?style=svg)][circleci]
[![Code Climate](https://codeclimate.com/github/salsify/goldiloader.svg)][codeclimate]
[![Coverage Status](https://coveralls.io/repos/salsify/goldiloader/badge.svg)][coveralls]

[gem]: https://rubygems.org/gems/goldiloader
[circleci]: https://circleci.com/gh/salsify/goldiloader
[codeclimate]: https://codeclimate.com/github/salsify/goldiloader
[coveralls]: https://coveralls.io/r/salsify/goldiloader

Wouldn't it be awesome if ActiveRecord didn't make you think about eager loading and it just did the "right" thing by default? With Goldiloader it can!

**This branch only supports Rails 6.1+ with Ruby 3.0+. For older versions of Rails/Ruby use
[4-x-stable](https://github.com/salsify/goldiloader/blob/4-x-stable/README.md),
[3-x-stable](https://github.com/salsify/goldiloader/blob/3-x-stable/README.md), [2-x-stable](https://github.com/salsify/goldiloader/blob/2-x-stable/README.md)
or [1-x-stable](https://github.com/salsify/goldiloader/blob/1-x-stable/README.md).**

Consider the following models:

```ruby
class Blog < ActiveRecord::Base
  has_many :posts
end

class Post < ActiveRecord::Base
  belongs_to :blog
end
```

Here are some sample queries without the Goldiloader:

```ruby
> blogs = Blog.limit(5).to_a
# SELECT * FROM blogs LIMIT 5

> blogs.each { |blog| blog.posts.to_a }
# SELECT * FROM posts WHERE blog_id = 1
# SELECT * FROM posts WHERE blog_id = 2
# SELECT * FROM posts WHERE blog_id = 3
# SELECT * FROM posts WHERE blog_id = 4
# SELECT * FROM posts WHERE blog_id = 5
```

Here are the same queries with the Goldiloader:

```ruby
> blogs = Blog.limit(5).to_a
# SELECT * FROM blogs LIMIT 5

> blogs.each { |blog| blog.posts.to_a }
# SELECT * FROM posts WHERE blog_id IN (1,2,3,4,5)
```

Whoa! It automatically loaded all of the posts for our five blogs in a single database query without specifying any eager loads! Goldiloader assumes that you'll access all models loaded from a query in a uniform way. The first time you traverse an association on any of the models it will eager load the association for all the models. It even works with arbitrary nesting of associations.

Read more about the motivation for the Goldiloader in this [blog post](http://www.salsify.com/blog/automatic-eager-loading-rails/).

## Installation

Add this line to your application's Gemfile:

    gem 'goldiloader'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install goldiloader

## Usage

By default all associations will be automatically eager loaded when they are first accessed so hopefully most use cases should require no additional configuration. Note you're still free to explicitly eager load associations via `eager_load`, `includes`, or `preload`.

### Disabling Automatic Eager Loading

You can disable automatic eager loading with `auto_include` query scope method:

```ruby
Blog.order(:name).auto_include(false)
```

Note this will not disable automatic eager loading for nested associations.

Automatic eager loading can be disabled for specific associations by customizing the association's scope:

```ruby
class Blog < ActiveRecord::Base
  has_many :posts, -> { auto_include(false) }
end
```

Automatic eager loading can be disabled globally disabled for all threads:

```ruby
# config/initializers/goldiloader.rb
Goldiloader.globally_enabled = false
```

Automatic eager loading can then be selectively enabled for particular sections of code:

```ruby
# Using a block form
Goldiloader.enabled do
  # Automatic eager loading is enabled for the current thread
  # ...
end

# Using a non-block form
Goldiloader.enabled = true
# Automatic eager loading is enabled for the current thread
# ...
Goldiloader.enabled = false
```

Similarly, you can selectively disable automatic eager loading for particular sections of code in a thread local manner:

```ruby
# Using a block form
Goldiloader.disabled do
  # Automatic eager loading is disabled for the current thread
  # ...
end

# Using a non-block form
Goldiloader.enabled = false
# Automatic eager loading is disabled for the current thread
# ...
Goldiloader.enabled = true
```

Note `Goldiloader.enabled=`, `Goldiloader.enabled`, and `Goldiloader.disabled` are thread local to ensure
proper thread isolation in multi-threaded servers like Puma.

### Association Options

Goldiloader supports a few options on ActiveRecord associations to customize its behavior.

#### fully_load

There are several association methods that ActiveRecord can either execute on in memory models or push down into SQL depending on whether or not the association is loaded. This includes the following methods:

* `first`
* `second`
* `third`
* `fourth`
* `fifth`
* `forty_two` (one of the hidden gems in Rails 4.1)
* `last`
* `size`
* `ids_reader`
* `empty?`
* `exists?`

This can cause problems for certain usage patterns if we're no longer specifying eager loads:

```ruby
> blogs = Blog.limit(5).to_a
# SELECT * FROM blogs LIMIT 5

> blogs.each do |blog|
    if blog.posts.exists?
      puts blog.posts
    else
      puts 'No posts'
  end
# SELECT 1 AS one FROM posts WHERE blog_id = 1 LIMIT 1
# SELECT * FROM posts WHERE blog_id IN (1,2,3,4,5)
```

Notice the first call to `blog.posts.exists?` was executed via SQL because the `posts` association wasn't yet loaded. The `fully_load` option can be used to force ActiveRecord to fully load the association (and do any necessary automatic eager loading) when evaluating methods like `exists?`:

```ruby
class Blog < ActiveRecord::Base
  has_many :posts, fully_load: true
end
```

## Limitations

Goldiloader leverages the ActiveRecord eager loader so it shares some of the same limitations. See [eager loading workarounds](#eager-loading-limitation-workarounds) for some potential workarounds.

### has_one associations that rely on a SQL limit

You should not try to auto eager load (or regular eager load) `has_one` associations that actually correspond to multiple records and rely on a SQL limit to only return one record. Consider the following example:

```ruby
class Blog < ActiveRecord::Base
  has_many :posts
  has_one :most_recent_post, -> { order(published_at: desc) }, class_name: 'Post'
end
```

With standard Rails lazy loading the `most_recent_post` association is loaded with a query like this:

```sql
SELECT * FROM posts WHERE blog_id = 1 ORDER BY published_at DESC LIMIT 1
```

With auto eager loading (or regular eager loading) the `most_recent_post` association is loaded with a query like this:

```sql
SELECT * FROM posts WHERE blog_id IN (1,2,3,4,5) ORDER BY published_at DESC
```

Notice the SQL limit can no longer be used which results in fetching all posts for each blog. This can cause severe performance problems if there are a large number of posts.

### Other Limitations

Associations with any of the following options cannot be eager loaded:

* `limit`
* `offset`
* `finder_sql`
* `group` (only applies to Rails < 5.0.7 and Rails 5.1.x < 5.1.5 due to a [Rails bug](https://github.com/rails/rails/issues/15854))
* `from` (only applies to Rails < 5.0.7 and Rails 5.1.x < 5.1.5 due to a Rails bug)

Goldiloader detects associations with any of these options and disables automatic eager loading on them.

It might still be possible to eager load these with Goldiloader by using [custom preloads](#custom-preloads).


### Eager Loading Limitation Workarounds

Most of the Rails limitations with eager loading can be worked around by pushing the problematic SQL into the database via database views. Consider the following example with associations that can't be eager loaded due to SQL limits:

```ruby
class Blog < ActiveRecord::Base
  has_many :posts
  has_one :most_recent_post, -> { order(published_at: desc) }, class_name: 'Post'
  has_many :recent_posts, -> { order(published_at: desc).limit(5) }, class_name: 'Post'
end
```
This can be reworked to push the order/limit into a database view:

```sql
CREATE VIEW most_recent_post_references AS
SELECT blogs.id AS blog_id, p.id as post_id
FROM blogs, LATERAL (
  SELECT posts.id
  FROM posts
  WHERE posts.blog_id = blogs.id
  ORDER BY published_at DESC
  LIMIT 1
) p

CREATE VIEW recent_post_references AS
SELECT blogs.id AS blog_id, p.id as post_id, p.published_at AS post_published_at
FROM blogs, LATERAL (
  SELECT posts.id, posts.published_at
  FROM posts
  WHERE posts.blog_id = blogs.id
  ORDER BY published_at DESC
  LIMIT 5
) p
```
The models would now be:
```ruby
class Blog < ActiveRecord::Base
  has_many :posts
  has_one :most_recent_post_reference
  has_one :most_recent_post, through: :most_recent_post_reference, source: :post
  has_many :recent_post_references, -> { order(post_published_at: desc) }
  has_many :recent_posts, through: :recent_post_reference, source: :post
end

class MostRecentPostReference < ActiveRecord::Base
  belongs_to :post
  belongs_to :blog
end

class RecentPostReference < ActiveRecord::Base
  belongs_to :post
  belongs_to :blog
end
```

## Custom Preloads

In addition to preloading relations, you can also define custom preloads by yourself in your model. The only requirement is that you need to be able to perform a lookup for multiple records/ids and return a single Hash with the ids as keys.
If that's the case, these preloads can nearly be anything. Some examples could be:

- simple aggregations (count, sum, maximum, etc.)
- more complex custom SQL queries
- external API requests (ElasticSearch, Redis, etc.)
- relations with primary keys stored in a `jsonb` column

Here's how:

```ruby
class Blog < ActiveRecord::Base
  has_many :posts
  
  def posts_count
    goldiload do |ids|
      # By default, `ids` will be an array of `Blog#id`s
      Post
        .where(blog_id: ids)
        .group(:blog_id)
        .count
    end
  end
end
```

The first time you call the `posts_count` method, it will call the block with all model ids from the current context and reuse the result from the block for all other models in the context.

A more complex example might use a custom primary key instead of `id`, use a non ActiveRecord API and have more complex return values than just scalar values:


```ruby
class Post < ActiveRecord::Base
  def main_translator_reference
    json_payload[:main_translator_reference]
  end
  
  def main_translator
    goldiload(key: :main_translator_reference) do |references|
      # `references` will be an array of `Post#main_translator_reference`s
      SomeExternalApi.fetch_translators(
        id: references
      ).index_by(&:id)
    end
  end
end
```

If you want to preload something that is based on multiple keys, you can also pass an array:

```ruby
class Meeting < ActiveRecord::Base
  def organizer_notes
    goldiload(key: [:organizer_id, :room_id]) do |id_sets|
      # +id_sets+ will be a two dimensional array with the
      # organizer_id and room_id for each item, e.g.
      # [
      #   [<organizer_id_1>, <room_id_1>],
      #   [<organizer_id_2>, <room_id_2>]
      # ]
      notes = logic_for_fetching_organizer_notes
      notes.group_by {|report|
        [report.organizer_id, report.room_id]
      }
    end
  end
end
```


**Note:** The `goldiload` method will use the `source_location` of the given block as a cache name to distinguish between multiple defined preloads. If this causes an issue for you, you can also pass a cache name explicitly as the first argument to the `goldiload` method.


### Gotchas

Even though the methods in the examples above (`posts_count`, `main_translator`) are actually instance methods, the block passed to `goldiload` should not contain any references to these instances, as this could break the internal lookup/caching mechanism. We prevent this for the `self` keyword, so you'll get a `NoMethodError`. If you get this, you might want to think about the implementation rather than just trying to work around the exception.


## Upgrading

### From 0.x, 1.x

The `auto_include` association option has been removed in favor of the `auto_include` query scope method.
Associations that specify this option must migrate to use the query scope method:

```ruby
class Blog < ActiveRecord::Base
  # Old syntax
  has_many :posts, auto_include: false

  # New syntax
  has_many :posts, -> { auto_include(false) }
end
```

## Status

This gem is tested with Rails 6.1, 7.0 and Edge using MRI 3.0, 3.1 and 3.2. 

Let us know if you find any issues or have any other feedback.

## Change log

See the [change log](https://github.com/salsify/goldiloader/blob/master/CHANGELOG.md).

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
