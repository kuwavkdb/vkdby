class AddIndexToOldPersonKeyOnUnitPeople < ActiveRecord::Migration[8.1]
  def change
    add_index :unit_people, :old_person_key
  end
end
