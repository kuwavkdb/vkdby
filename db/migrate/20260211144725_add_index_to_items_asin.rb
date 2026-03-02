# frozen_string_literal: true

class AddIndexToItemsAsin < ActiveRecord::Migration[8.1]
  def change
    add_index :items, :asin, unique: true
  end
end
