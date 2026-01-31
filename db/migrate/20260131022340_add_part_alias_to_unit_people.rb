# frozen_string_literal: true

class AddPartAliasToUnitPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :unit_people, :part_alias, :string
  end
end
