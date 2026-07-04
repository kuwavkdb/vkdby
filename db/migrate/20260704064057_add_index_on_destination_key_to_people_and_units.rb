# frozen_string_literal: true

class AddIndexOnDestinationKeyToPeopleAndUnits < ActiveRecord::Migration[8.1]
  def change
    add_index :units, :destination_key, where: 'destination_key IS NOT NULL'
    add_index :people, :destination_key, where: 'destination_key IS NOT NULL'
  end
end
