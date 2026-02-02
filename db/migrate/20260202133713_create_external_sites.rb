# frozen_string_literal: true

class CreateExternalSites < ActiveRecord::Migration[8.1]
  def change
    create_table :external_sites do |t|
      t.string :site_key, null: false
      t.string :url_pattern, null: false

      t.timestamps
    end
    add_index :external_sites, :site_key, unique: true
  end
end
