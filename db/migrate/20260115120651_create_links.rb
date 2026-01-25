# frozen_string_literal: true

class CreateLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :links do |t|
      t.string :text
      t.string :url, null: false
      t.references :linkable, polymorphic: true, null: false
      t.integer :sort_order
      t.boolean :active, default: true

      t.timestamps
    end
  end
end
