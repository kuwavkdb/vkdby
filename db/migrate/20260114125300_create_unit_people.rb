# frozen_string_literal: true

class CreateUnitPeople < ActiveRecord::Migration[8.1]
  def change
    create_table :unit_people do |t|
      t.references :unit, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.integer :status

      t.timestamps
    end
  end
end
