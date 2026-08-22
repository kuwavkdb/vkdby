# frozen_string_literal: true

class RemoveCurrentIndexFromUnitSnapshots < ActiveRecord::Migration[8.1]
  def change
    # Admin::UnitsController#edit/update の並び順を past を含む形に統一したため、
    # (unit_id, current, snapshot_index) を使うクエリがなくなり、
    # index_unit_snapshots_on_unit_id_and_past_and_current_and_index で代替できる
    remove_index :unit_snapshots, column: %i[unit_id current snapshot_index],
                                  name: 'index_unit_snapshots_on_unit_id_and_current_and_index'
  end
end
