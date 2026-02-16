class AddSnapshotIndexToUnitSnapshots < ActiveRecord::Migration[8.1]
  def change
    add_column :unit_snapshots, :snapshot_index, :integer, null: false, default: 0
    
    # 既存のインデックスを削除
    remove_index :unit_snapshots, name: "index_unit_snapshots_on_unit_id_and_current", if_exists: true
    
    # 新しいインデックスを追加
    add_index :unit_snapshots, [:unit_id, :current, :snapshot_index], name: "index_unit_snapshots_on_unit_id_and_current_and_index"
  end
end
