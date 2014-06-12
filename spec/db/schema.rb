# encoding: UTF-8

ActiveRecord::Schema.define(:version => 0) do

  create_table(:blogs, force: true) do |t|
    t.string :name
  end

  create_table(:posts, force: true) do |t|
    t.text :title
    t.integer :blog_id
  end

end

class Blog < ActiveRecord::Base
  has_many :posts

  if Goldiloader::Compatibility.mass_assignment_security_enabled?
    attr_accessible :name
  end

end

class Post < ActiveRecord::Base
  has_one :blog

  if Goldiloader::Compatibility.mass_assignment_security_enabled?
    attr_accessible :title
  end
end
