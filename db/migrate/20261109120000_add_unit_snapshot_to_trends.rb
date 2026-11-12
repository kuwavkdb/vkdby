# frozen_string_literal: true

# 動向からスナップショットを日付ではなくIDで指すようにし、日付のないスナップショットも選べるようにする（issue #2031）
class AddUnitSnapshotToTrends < ActiveRecord::Migration[8.1]
  def up
    add_reference :trends, :unit_snapshot, foreign_key: { on_delete: :nullify }

    # 既存の snapshot_date 指定を、1件目のユニットの同じ日付のスナップショットのIDへ移し替える
    execute <<~SQL.squish
      UPDATE trends
      SET unit_snapshot_id = unit_snapshots.id
      FROM unit_snapshots
      WHERE trends.snapshot_date IS NOT NULL
        AND unit_snapshots.snapshot_date = trends.snapshot_date
        AND unit_snapshots.unit_id = (trends.units -> 0 ->> 'unit_id')::bigint
    SQL
  end

  def down
    remove_reference :trends, :unit_snapshot, foreign_key: true
  end
end
