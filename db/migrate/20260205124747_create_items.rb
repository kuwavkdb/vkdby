# frozen_string_literal: true

class CreateItems < ActiveRecord::Migration[8.0]
  def change
    create_table :items do |t|
      t.string :title, null: false
      t.jsonb :artists, null: false, default: []
      t.date :release_date, null: false
      t.string :image_url
      t.string :link_url, null: false
      t.string :asin
      t.integer :old_item_id

      t.timestamps
    end

    add_index :items, :title
    add_index :items, :artists, using: :gin
    add_index :items, :release_date
    add_index :items, :link_url, unique: true
  end
end
