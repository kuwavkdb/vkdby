class ChangeSnapshotDateToNullableInUnitSnapshots < ActiveRecord::Migration[8.1]
  def change
    # snapshot_date を nullable に変更
    change_column_null :unit_snapshots, :snapshot_date, true
    
    # uniqueness インデックスを削除（nil を含む可能性があるため）
    remove_index :unit_snapshots, name: 'index_unit_snapshots_on_unit_id_and_snapshot_date'
  end
end
