# frozen_string_literal: true

class AddOldKeyToCustomPages < ActiveRecord::Migration[8.1]
  def change
    add_column :custom_pages, :old_key, :string
    add_index :custom_pages, :old_key, unique: true
  end
end
