# frozen_string_literal: true

class AddSupportToUnitPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :unit_people, :support, :boolean, default: false, null: false
  end
end
