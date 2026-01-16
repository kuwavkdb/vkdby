class AddPartToUnitPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :unit_people, :part, :integer, null: false, default: 0
  end
end
