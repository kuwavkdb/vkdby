# frozen_string_literal: true

class AddUnknownFlagsToTrends < ActiveRecord::Migration[8.1]
  def change
    add_column :trends, :day_unknown, :boolean, default: false, null: false
    add_column :trends, :month_unknown, :boolean, default: false, null: false
  end
end
