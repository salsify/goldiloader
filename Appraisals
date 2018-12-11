# frozen_string_literal: true

appraise 'rails-4.2' do
  gem 'activerecord', '4.2.10'
  gem 'activesupport', '4.2.10'

  # activerecord-jdbcsqlite3-adapter > 50 doesn't work with Rails 4.2
  gem 'activerecord-jdbcsqlite3-adapter', '~> 1.3.24', platforms: :jruby
end

appraise 'rails-5.0' do
  gem 'activerecord', '5.0.7'
  gem 'activesupport', '5.0.7'
end

appraise 'rails-5.1' do
  gem 'activerecord', '5.1.6'
  gem 'activesupport', '5.1.6'
end

appraise 'rails-5.2' do
  gem 'activerecord', '5.2.2 '
  gem 'activesupport', '5.2.2 '
end

appraise 'rails-edge' do
  gem 'activerecord', github: 'rails/rails'
  gem 'activesupport', github: 'rails/rails'
end
