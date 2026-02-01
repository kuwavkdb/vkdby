# frozen_string_literal: true

class CreateTrends < ActiveRecord::Migration[8.1]
  def change
    create_table :trends do |t|
      t.date :date, null: false
      t.jsonb :units
      t.jsonb :people
      t.text :content
      t.text :quote
      t.string :quote_url
      t.string :quote_title
      t.string :via_url
      t.string :via_name
      t.boolean :active, default: true, null: false
      t.datetime :publish_start_at, null: false
      t.integer :unit_phenomenon
      t.integer :person_phenomenon
      t.integer :etc_phenomenon
      t.integer :old_trend_id
      t.integer :old_wiki_id

      t.timestamps
    end
  end
end
