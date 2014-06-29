# Changelog

### 0.0.6 (unreleased)

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

