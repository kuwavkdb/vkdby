# frozen_string_literal: true

class CreateCustomPages < ActiveRecord::Migration[8.1]
  def change
    create_table :custom_pages do |t|
      t.string   :key, null: false
      t.string   :title, null: false
      t.text     :body
      t.boolean  :active, null: false, default: false
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :custom_pages, :key, unique: true
    add_index :custom_pages, :discarded_at
  end
end
