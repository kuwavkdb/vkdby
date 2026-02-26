# frozen_string_literal: true

class AddAliasesToUnitsAndPeople < ActiveRecord::Migration[8.0]
  def change
    add_column :units,  :aliases, :jsonb, default: [], null: false
    add_column :people, :aliases, :jsonb, default: [], null: false

    add_index :units,  :aliases, using: :gin
    add_index :people, :aliases, using: :gin
  end
end
