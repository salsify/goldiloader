# encoding: UTF-8

ActiveRecord::Schema.define(:version => 0) do

  create_table(:blogs, force: true) do |t|
    t.string :name
  end

  create_table(:posts, force: true) do |t|
    t.text :title
    t.text :body
    t.integer :blog_id
  end
end
