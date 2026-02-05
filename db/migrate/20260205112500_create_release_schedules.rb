# frozen_string_literal: true

class CreateReleaseSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :release_schedules do |t|
      t.string :artist, default: '', null: false
      t.string :wiki
      t.string :title
      t.datetime :release_date # null: true to allow handling 0000-00-00 as nil
      t.datetime :created_at # Override timestamps to match dump
      t.string :type, default: '', null: false
      t.string :plugin_text, default: '', null: false
      t.text :plugin_full
      t.text :append_before
      t.text :append_after
      t.string :publisher
      t.string :product_group
      t.string :img_url
      t.string :l_img_url
      t.text :url
      t.text :tracks
      t.datetime :updated_at # Override timestamps to match dump
      t.string :asin
      t.string :tower_id

      t.index :plugin_text, unique: true
      t.index %i[wiki release_date]
      t.index :asin
    end
  end
end
