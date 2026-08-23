# frozen_string_literal: true

class AddDiscardedAtToItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :discarded_at, :datetime
    add_index :items, :discarded_at
  end
end
