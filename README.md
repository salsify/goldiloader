# Goldiloader

[![Gem Version](https://badge.fury.io/rb/goldiloader.png)][gem]
[![Build Status](https://secure.travis-ci.org/salsify/goldiloader.png?branch=master)][travis]
[![Code Climate](https://codeclimate.com/github/salsify/goldiloader.png)][codeclimate]
[![Coverage Status](https://coveralls.io/repos/salsify/goldiloader/badge.png)][coveralls]

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

## Installation

Add this line to your application's Gemfile:

    gem 'goldiloader'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install goldiloader

## Usage

By default all associations will be automatically eager loaded when they are first accessed so hopefully most use cases should require no additional configuration. 

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
* `forth`
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

## Status

This gem is tested with Rails 3.2, 4.0, and 4.1 using MRI 1.9.3, 2.0.0, 2.1.0 and JRuby in 1.9 mode. [Salsify](http://salsify.com) is not yet using this gem in production so proceed with caution. Let us know if you find any issues or have any other feedback. 

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
