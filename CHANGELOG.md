# Changelog

### 0.0.12 (unreleased)
* Rails 5.1 support
* Fix [issue 42](https://github.com/salsify/goldiloader/issues/42) - inverse_of now work properly in Rails 5.x.

### 0.0.11
* Fix [issue 34](https://github.com/salsify/goldiloader/issues/34) - HABTM associations now honor 
  the auto_include option.
* Fix [issue 39](https://github.com/salsify/goldiloader/issues/39) - `CollectionProxy#exists?` should return false 
  for a new model's association with no values.
  
### 0.0.10
* Fix [issue 13](https://github.com/salsify/goldiloader/issues/13) - Eager load associations with unscope
  in Rails 4.1.9+ now that the underlying Rails bug has been fixed.
* Fix [issue 11](https://github.com/salsify/goldiloader/issues/11) - Eager load associations with joins in 
  Rails 4.2+ now that the underlying Rails bug has been fixed.
* Initial support for Rails 5. There are no known issues but see 
  [issue 27](https://github.com/salsify/goldiloader/issues/27) for remaining tasks.
* MRI 2.3.0 support.
* JRuby 9000 support.

### 0.0.9
* Merge [pull request](https://github.com/salsify/goldiloader/pull/24) - Optimization: Cache compatibility
  checks. **Thanks Jonathan Calvert!**

### 0.0.8
* Fix [issue 23](https://github.com/salsify/goldiloader/issues/23) - Handle polymorphic belongs_to
  associations in Rails 4 that have a mix of non-nil and nil values.

### 0.0.7
* Fix [issue 20](https://github.com/salsify/goldiloader/issues/20) by not auto-eager loading 
  associations that are instance dependent. Eager loading these associations produces potentially
  incorrect results and leads to a deprecation warning in Rails 4.2.
* Fix [issue 21](https://github.com/salsify/goldiloader/issues/21) - Handle explicit eager loads
  of singular associations that are nil.
* Rails 4.2 support.

### 0.0.6
* Workaround [issue 16](https://github.com/salsify/goldiloader/issues/16) by not auto-eager loading 
  has_and_belongs_to_many associations with a uniq in Rails 3.2 since Rails doesn't eager load them 
  properly.
* Fix [issue 17](https://github.com/salsify/goldiloader/issues/17) - models eager loaded via an explicit
  call to eager_load now auto eager load nested models.

### 0.0.5

* Fix ActiveRecord and ActiveSupport dependencies to work with versions greater than 4.1.0. Thanks for the pull
  requests [Alexey Volodkin](https://github.com/miraks) and [Philip Claren](https://github.com/DerKobe).
* Workaround [issue 13](https://github.com/salsify/goldiloader/issues/13) by not auto-eager loading associations
  that use `unscope`. This workaround will be removed when the underlying 
  [bug 11036](https://github.com/rails/rails/issues/11036) in the Rails eager loader is fixed.
* Workaround [issue 11](https://github.com/salsify/goldiloader/issues/11) by not auto-eager loading associations
  that use `joins`. This workaround will be removed when the underlying 
  [bug 11518](https://github.com/rails/rails/pull/11518) in the Rails eager loader is fixed.
* Fix [issue 15](https://github.com/salsify/goldiloader/issues/15) - Don't auto eager load associations 
  with finder_sql in Rails 4.0. Previously this was only done for Rails 3.2.

### 0.0.4
 
* Fix [issue 3](https://github.com/salsify/goldiloader/issues/3) - `exists?` method should take an argument. 
  Thanks for reporting [Bert Goethals](https://github.com/Bertg)
* Fix [issue 4](https://github.com/salsify/goldiloader/issues/4) - Associations couldn't be loaded in after 
  destroy callbacks. Thanks for reporting [Bert Goethals](https://github.com/Bertg)
* Fix [issue 6](https://github.com/salsify/goldiloader/issues/6) - Models in read only associations weren't
  being marked as read only
* Fix [issue 7](https://github.com/salsify/goldiloader/issues/7) - Don't attempt to eager load associations that
  aren't eager loadable e.g. if they have a limit
* Fix [issue 8](https://github.com/salsify/goldiloader/issues/8) - Handle eager loading associations whose 
  accessor methods have been overridden.

