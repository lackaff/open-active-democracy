class CreateCategories < ActiveRecord::Migration
  def self.up
    create_table :categories, :force => true do |t|
      t.column :name, :string
    end
  end

  def self.down
    drop_table :categories
  end
end
