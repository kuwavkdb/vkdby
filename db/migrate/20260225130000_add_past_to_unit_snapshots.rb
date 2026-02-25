# frozen_string_literal: true

class AddPastToUnitSnapshots < ActiveRecord::Migration[8.1]
  def change
    add_column :unit_snapshots, :past, :boolean, null: false, default: false
  end
end
