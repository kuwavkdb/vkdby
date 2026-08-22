# frozen_string_literal: true

class AddPastIndexToUnitSnapshots < ActiveRecord::Migration[8.1]
  def change
    # past ASC, current DESC, snapshot_index ASC の並び順（ProfilesController#load_unit_data /
    # Admin::UnitSnapshotsController#index）に完全一致させ、ソート処理を省略できるようにする
    add_index :unit_snapshots, %i[unit_id past current snapshot_index],
              order: { current: :desc },
              name: 'index_unit_snapshots_on_unit_id_and_past_and_current_and_index'
  end
end
