class AddParentTagToPartners < ActiveRecord::Migration
  def self.up
    add_column :partners, :parent_tag, :string
  end

  def self.down
  end
end
