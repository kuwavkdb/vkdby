# frozen_string_literal: true

class AddIndexesToTrends < ActiveRecord::Migration[8.1]
  def change
    add_index :trends, :date
    add_index :trends, :units, using: :gin
  end
end
