class FixUserLogin < ActiveRecord::Migration
  def up
    change_column_default(:users, :status, "pending")
  end

  def down
  end
end
