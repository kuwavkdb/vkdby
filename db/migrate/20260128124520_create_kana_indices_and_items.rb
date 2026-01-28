# frozen_string_literal: true

class CreateKanaIndicesAndItems < ActiveRecord::Migration[8.1]
  def change
    create_table :kana_indices do |t|
      t.string :name, null: false

      t.timestamps
    end
    add_index :kana_indices, :name, unique: true

    create_table :kana_index_items do |t|
      t.references :kana_index, null: false, foreign_key: true
      t.references :indexable, polymorphic: true, null: false

      t.timestamps
    end
    # Index for fast lookup of "which items are in this index"
    add_index :kana_index_items, %i[kana_index_id indexable_type]
    # Index for fast lookup of "which indexes does this item belong to" (already covered by polymorphic reference but ensuring composite)
    # t.references creates index on [indexable_type, indexable_id] by default usually, but let's be safe if needed or rely on default.
    # The default t.references :indexable, polymorphic: true creates index on [indexable_type, indexable_id]

    # Performance optimization for sorting
    add_index :units, :name_kana
    add_index :people, :name_kana
  end
end
