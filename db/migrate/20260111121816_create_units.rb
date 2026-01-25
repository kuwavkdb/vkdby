# frozen_string_literal: true

class CreateUnits < ActiveRecord::Migration[8.1]
  def change
    create_table :units do |t|
      t.string :name
      t.string :name_kana
      t.integer :status
      t.integer :unit_type

      t.timestamps
    end
  end
end
