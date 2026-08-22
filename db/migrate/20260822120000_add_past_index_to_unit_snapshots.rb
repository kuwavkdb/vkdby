# frozen_string_literal: true

class AddPastIndexToUnitSnapshots < ActiveRecord::Migration[8.1]
  def change
    add_index :unit_snapshots, %i[unit_id past current snapshot_index],
              name: 'index_unit_snapshots_on_unit_id_and_past_and_current_and_index'
  end
end
