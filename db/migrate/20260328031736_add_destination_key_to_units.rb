class AddDestinationKeyToUnits < ActiveRecord::Migration[8.1]
  def change
    add_column :units, :destination_key, :string
  end
end
