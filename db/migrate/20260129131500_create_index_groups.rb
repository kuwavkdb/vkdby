class CreateIndexGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :index_groups do |t|
      t.string :name, null: false
      t.integer :sort_order, default: 0, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    reversible do |dir|
      dir.up do
        execute "INSERT INTO index_groups (id, name, sort_order, created_at, updated_at) VALUES (1, 'カナ索引', 1, NOW(), NOW())"
        execute "INSERT INTO index_groups (id, name, sort_order, created_at, updated_at) VALUES (2, '個人カナ索引', 2, NOW(), NOW())"
      end
    end

    rename_column :tag_indices, :index_group, :index_group_id
    add_foreign_key :tag_indices, :index_groups
    add_index :tag_indices, :index_group_id
  end
end
