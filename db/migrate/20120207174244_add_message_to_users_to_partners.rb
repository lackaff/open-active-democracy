class AddMessageToUsersToPartners < ActiveRecord::Migration
  def self.up
    add_column :partners, :message_to_users, :text
  end

  def self.down
  end
end
