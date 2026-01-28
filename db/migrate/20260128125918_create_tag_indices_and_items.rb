# frozen_string_literal: true

class CreateTagIndicesAndItems < ActiveRecord::Migration[8.1]
  def change
    create_table :tag_indices do |t|
      t.string :name, null: false
      t.integer :index_group
      t.integer :order_in_group

      t.timestamps
    end
    add_index :tag_indices, :name, unique: true
    add_index :tag_indices, %i[index_group order_in_group]

    create_table :tag_index_items do |t|
      t.references :tag_index, null: false, foreign_key: true
      t.references :indexable, polymorphic: true, null: false

      t.timestamps
    end
    add_index :tag_index_items, %i[tag_index_id indexable_type]

    # Drop old tables
    drop_table :kana_index_items
    drop_table :kana_indices
  end
end
