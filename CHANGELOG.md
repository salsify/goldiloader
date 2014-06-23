# Changelog

### 0.0.5 (Unreleased)

* Fix ActiveRecord and ActiveSupport dependencies to work with versions greater than 4.1.0. Thanks for the pull
  requests [Alexey Volodkin](https://github.com/miraks) and [Philip Claren](https://github.com/DerKobe).

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

