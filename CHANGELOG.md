# Changelog

### 4.0.1
- Fix issue [105](https://github.com/salsify/goldiloader/issues/105) - Handle polymorphic associations with scopes.

### 4.0.0
- Fix Rails Edge for changes in `ActiveRecord::Associations::Preloader` API.
- Add support for Ruby 3.0.  
- Drop support for Rails < 5.2.
- Drop support for Ruby < 2.6.

### 3.2.0
- Rails 6.1 support.

### 3.1.1
- Fix to support Rails 6.0 beta 3.

### 3.1.0
- Initial support for Rails 6.0.

### 3.0.3
- Optimize association eager loadable checks by caching information on the association's reflection.
- Optimize association eager loading if we're only eager loading associations for a single model.

### 3.0.2
- Fix destroyed model eager loading which accidentally broke in [#74](https://github.com/salsify/goldiloader/pull/74).

### 3.0.1
- Enable eager loading of associations on destroyed models in all versions of Rails except 5.2.0 since
  Rails issue [32375](https://github.com/rails/rails/pull/32375) has been fixed.
- Optimize checks to see if an association is eager loadable.

### 3.0.0
* Drop support for Ruby <= 2.2.
* Use frozen string literals.

### 2.1.2 
* Fix [issue 61](https://github.com/salsify/goldiloader/issues/61) - don't eager load has_one associations with an order.
  **Thanks @sobrinho**

### 2.1.1
* Enable eager loading of associations with a `from` or `group` in Rails 5.0.x >= 5.0.7 and Rails >= 5.1.5 because
  the underlying Rails bug has been fixed.
  
### 2.1.0
* Rails 5.2 support.

### 2.0.1
* No code changes. Fix bad deploy.

### 2.0.0
* Add `auto_include` query scope method.
* Remove `auto_include` association option in favor of using the `auto_include` query scope method.
* Add Rails 5.1 support.
* Drop Rails 3.2, 4.0 and 4.1 and Ruby 1.9 and 2.0 support.
* Change ActiveRecord monkey patching to use `Module#prepend` instead of `alias_method_chain`.

### 1.0.0
* Version bump only release

### 0.0.12
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

