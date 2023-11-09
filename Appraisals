# frozen_string_literal: true

appraise 'rails-5.2' do
  gem 'activerecord', '5.2.8.1'
  gem 'activesupport', '5.2.8.1'
  gem 'rails', '5.2.8.1'

  install_if "-> { RUBY_VERSION < '2.7' }" do
    gem 'sqlite3', '1.5.4'
  end
end

appraise 'rails-6.0' do
  gem 'activerecord', '6.0.6'
  gem 'activesupport', '6.0.6'
  gem 'rails', '6.0.6'

  install_if "-> { RUBY_VERSION < '2.7' }" do
    gem 'sqlite3', '1.5.4'
  end
end

appraise 'rails-6.1' do
  gem 'activerecord', '6.1.7'
  gem 'activesupport', '6.1.7'
  gem 'rails', '6.1.7'

  install_if "-> { RUBY_VERSION < '2.7' }" do
    gem 'sqlite3', '1.5.4'
  end
end

appraise 'rails-7.0' do
  gem 'activerecord', '7.0.4'
  gem 'activesupport', '7.0.4'
  gem 'rails', '7.0.4'

  install_if "-> { RUBY_VERSION < '2.7' }" do
    gem 'sqlite3', '1.5.4'
  end
end

appraise 'rails-edge' do
  gem 'activerecord', github: 'rails/rails', branch: 'main'
  gem 'activesupport', github: 'rails/rails', branch: 'main'
  gem 'rails', github: 'rails/rails', branch: 'main'

  install_if "-> { RUBY_VERSION < '2.7' }" do
    gem 'sqlite3', '1.5.4'
  end
end
