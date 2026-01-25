# frozen_string_literal: true

class AddPeriodAndOrderToUnitPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :unit_people, :period, :integer, null: false, default: 1
    add_column :unit_people, :order_in_period, :integer, null: false, default: 1
    add_index :unit_people, %i[unit_id period order_in_period]
  end
end
