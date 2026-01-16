class AddKeysAndIndexesToPeopleAndUnits < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :key, :string
    add_column :people, :old_key, :string
    add_column :units, :key, :string
    add_column :units, :old_key, :string

    add_index :people, :key, unique: true
    add_index :people, :old_key, unique: true
    add_index :people, :name
    add_index :units, :key, unique: true
    add_index :units, :old_key, unique: true
    add_index :units, :name
  end
end
