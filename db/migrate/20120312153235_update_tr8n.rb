class UpdateTr8n < ActiveRecord::Migration
  def up
    add_column :tr8n_translators, :remote_id, :integer
    add_column :tr8n_translation_keys, :synced_at, :timestamp
    add_column :tr8n_translations, :synced_at, :timestamp

    create_table :tr8n_translation_source_languages do |t|
      t.integer   :language_id
      t.integer   :translation_source_id
      t.timestamps
    end
    add_index :tr8n_translation_source_languages, [:language_id, :translation_source_id], :name => :tr8n_tsl_lt

    create_table :tr8n_sync_logs do |t|
      t.timestamp :started_at
      t.timestamp :finished_at
      t.integer   :keys_sent
      t.integer   :translations_sent
      t.integer   :keys_received
      t.integer   :translations_received
      t.timestamps
    end
  end

  def down
  end
end
