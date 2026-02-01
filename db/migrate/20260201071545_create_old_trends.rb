# frozen_string_literal: true

class CreateOldTrends < ActiveRecord::Migration[8.1]
  def change
    create_table :old_trends do |t|
      t.integer :wikipage_id
      t.string :target_name
      t.string :target_date
      t.text :content
      t.text :quote
      t.string :quote_url
      t.string :via
      t.string :via_url
      t.boolean :publish
      t.datetime :publish_plan_date
      t.boolean :rss
      t.integer :hide_member
      t.integer :trend_class

      t.timestamps
    end
  end
end
