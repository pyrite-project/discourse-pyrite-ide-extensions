# frozen_string_literal: true

class CreatePyriteExtensionScopes < ActiveRecord::Migration[8.0]
  def change
    create_table :pyrite_extension_scopes do |t|
      t.string :name, null: false, limit: 214
      t.integer :owner_id, null: false
      t.timestamps
    end

    add_index :pyrite_extension_scopes, :name, unique: true
    add_index :pyrite_extension_scopes, :owner_id

    # Preserve the first creator for scopes already present in a development registry.
    reversible do |direction|
      direction.up do
        execute <<~SQL
          INSERT INTO pyrite_extension_scopes (name, owner_id, created_at, updated_at)
          SELECT DISTINCT ON (split_part(ext_id, '/', 1))
            split_part(ext_id, '/', 1), owner_id, created_at, created_at
          FROM pyrite_extensions
          WHERE ext_id LIKE '@%/%'
          ORDER BY split_part(ext_id, '/', 1), created_at, id
        SQL
      end
    end
  end
end
