class AddOldPersonKeyToUnitPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :unit_people, :old_person_key, :string
  end
end
