# Goldiloader

[![Gem Version](https://badge.fury.io/rb/goldiloader.png)][gem]
[![Build Status](https://secure.travis-ci.org/salsify/goldiloader.png?branch=master)][travis]
[![Code Climate](https://codeclimate.com/github/salsify/goldiloader.png)][codeclimate]
[![Coverage Status](https://coveralls.io/repos/salsify/goldiloader/badge.png)][coveralls]

[gem]: https://rubygems.org/gems/goldiloader
[travis]: http://travis-ci.org/salsify/goldiloader
[codeclimate]: https://codeclimate.com/github/salsify/goldiloader
[coveralls]: https://coveralls.io/r/salsify/goldiloader

Wouldn't it be awesome if ActiveRecord didn't make you think about eager loading and it just did the "right" thing by default? With Goldiloader it can!

Consider the following models:

```
class Blog < ActiveRecord::Base
  has_many :posts
end

class Post < ActiveRecord::Base
  belongs_to :blog
end
```

Here are some sample queries without the Goldiloader:

```
> blogs = Blogs.limit(5).to_a
# SELECT * FROM blogs LIMIT 5

> blogs.each { |blog| blog.posts.to_a }
# SELECT * FROM posts WHERE blog_id = 1
# SELECT * FROM posts WHERE blog_id = 2
# SELECT * FROM posts WHERE blog_id = 3
# SELECT * FROM posts WHERE blog_id = 4
# SELECT * FROM posts WHERE blog_id = 5
```

Here are the same queries with the Goldiloader:

```
> blogs = Blogs.limit(5).to_a
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

### Association Options

Goldiloader supports a few options on ActiveRecord associations to customize its behavior.

#### auto_include

You can disable automatic eager loading on specific associations with the `auto_include` option:

```
class Blog < ActiveRecord::Base
  has_many :posts, auto_include: false
end
```

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

```
> blogs = Blogs.limit(5).to_a
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

```
class Blog < ActiveRecord::Base
  has_many :posts, fully_load: true
end
```

## Limitations

Goldiloader leverages the ActiveRecord eager loader so it shares some of the same limitations. 

### has_one associations that rely on a SQL limit

You should not try to auto eager load (or regular eager load) `has_one` associations that actually correspond to multiple records and rely on a SQL limit to only return one record. Consider the following example:

```
class Blog < ActiveRecord::Base
  has_many :posts
  has_one :most_recent_post, -> { order(published_at: desc) }, class_name: 'Post'
end
```

With standard Rails lazy loading the `most_recent_post` association is loaded with a query like this:

```
SELECT * FROM posts WHERE blog_id = 1 ORDER BY published_at DESC LIMIT 1
```

With auto eager loading (or regular eager loading) the `most_recent_post` association is loaded with a query like this:

```
SELECT * FROM posts WHERE blog_id IN (1,2,3,4,5) ORDER BY published_at DESC
```

Notice the SQL limit can no longer be used which results in fetching all posts for each blog. This can cause severe performance problems if there are a large number of posts. 

### Other Limitations

Associations with any of the following options cannot be eager loaded:

* `limit`
* `offset`
* `finder_sql`
* `group` (due to a Rails bug)
* `from` (due to a Rails bug)
* `unscope` (due to a Rails bug)
* `joins` (due to a Rails bug)
* `uniq` (only Rails 3.2 - due to a Rails bug)

Goldiloader detects associations with any of these options and disables automatic eager loading on them.

## Status

This gem is tested with Rails 3.2, 4.0, 4.1, and 4.2 using MRI 1.9.3, 2.0.0, 2.1.0 and JRuby in 1.9 mode. 

Let us know if you find any issues or have any other feedback. 

## Change log

See the [change log](https://github.com/salsify/goldiloader/blob/master/CHANGELOG.md).

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
