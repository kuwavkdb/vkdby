# frozen_string_literal: true

class AddPersonColumnsToUnitPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :unit_people, :person_name, :string
    add_column :unit_people, :person_key, :string
    change_column_null :unit_people, :person_id, true
  end
end
