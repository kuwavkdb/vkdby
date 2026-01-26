# frozen_string_literal: true

class AddNoteToPeopleAndUnits < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :note, :text
    add_column :units, :note, :text
  end
end
