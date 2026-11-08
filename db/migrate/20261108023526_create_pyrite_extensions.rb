# frozen_string_literal: true

class CreatePyriteExtensions < ActiveRecord::Migration[8.0]
  def change
    create_table :pyrite_extensions do |t|
      t.string :ext_id, null: false, limit: 128
      t.string :name, null: false, limit: 100
      t.string :summary, limit: 280
      t.string :repo_url, limit: 1000
      t.string :homepage_url, limit: 1000
      t.string :license, limit: 64
      t.integer :owner_id, null: false
      t.integer :topic_id
      t.bigint :latest_release_id
      t.integer :moderation_level, null: false, default: 0
      t.string :moderation_severity, limit: 16
      t.text :moderation_message
      t.timestamps
    end

    add_index :pyrite_extensions, :ext_id, unique: true
    add_index :pyrite_extensions, :topic_id, unique: true
    add_index :pyrite_extensions, :owner_id

    create_table :pyrite_extension_releases do |t|
      t.bigint :extension_id, null: false
      t.string :version, null: false, limit: 64
      t.integer :upload_id
      t.string :sha256, null: false, limit: 64
      t.bigint :size, null: false
      t.jsonb :manifest, null: false, default: {}
      t.text :changelog
      t.integer :downloads_count, null: false, default: 0
      t.integer :moderation_level, null: false, default: 0
      t.string :moderation_severity, limit: 16
      t.text :moderation_message
      t.datetime :published_at, null: false
      t.timestamps
    end

    add_index :pyrite_extension_releases, %i[extension_id version], unique: true

    create_table :pyrite_extension_moderation_events do |t|
      t.bigint :extension_id, null: false
      t.bigint :release_id
      t.integer :actor_id, null: false
      t.integer :level, null: false
      t.string :severity, limit: 16
      t.text :public_message
      t.text :internal_note
      t.timestamps
    end

    add_index :pyrite_extension_moderation_events, %i[extension_id created_at]
  end
end
