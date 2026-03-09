# frozen_string_literal: true

class AddActiveToUnitSnapshots < ActiveRecord::Migration[8.1]
  def change
    add_column :unit_snapshots, :active, :boolean, default: true, null: false
  end
end
