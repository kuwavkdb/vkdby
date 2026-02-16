# frozen_string_literal: true

class AddUnitPersonColumnsToSnapshotPeople < ActiveRecord::Migration[8.1]
  def change
    # 既存の part (string) カラムを削除
    remove_column :snapshot_people, :part, :string

    # unit_people と同じカラムを追加
    add_column :snapshot_people, :old_person_key, :string
    add_column :snapshot_people, :person_key, :string
    add_column :snapshot_people, :part, :integer, default: 0, null: false # enum: vocal=0, guitar=1, bass=2, drums=3, keyboard=4, dj=5, unknown=99
    add_column :snapshot_people, :part_alias, :string
    add_column :snapshot_people, :status, :integer, default: 1, null: false # enum: undefined=0, active=1, pending=2, left=3, concerned=4, pre=5
    add_column :snapshot_people, :support, :boolean, default: false, null: false
    add_column :snapshot_people, :sns, :json
    add_column :snapshot_people, :inline_history, :text

    # インデックスを追加
    add_index :snapshot_people, :old_person_key
    add_index :snapshot_people, :person_key
  end
end
