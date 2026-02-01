# frozen_string_literal: true

class AddTitleAndPeopleIndexToTrends < ActiveRecord::Migration[8.1]
  def change
    add_column :trends, :title, :string
    add_index :trends, :people, using: :gin
  end
end
