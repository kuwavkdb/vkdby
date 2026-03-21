# frozen_string_literal: true

class AddIndexUnitPhenomenonToTrends < ActiveRecord::Migration[8.1]
  def change
    add_index :trends, :unit_phenomenon
  end
end
