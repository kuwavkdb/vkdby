# frozen_string_literal: true

class CreateUnitSnapshotsAndSnapshotPeople < ActiveRecord::Migration[8.1]
  def change
    create_table :unit_snapshots do |t|
      t.references :unit, null: false, foreign_key: true
      t.date :snapshot_date, null: false
      t.string :label
      t.boolean :current, default: false, null: false

      t.timestamps
    end

    add_index :unit_snapshots, %i[unit_id snapshot_date], unique: true
    add_index :unit_snapshots, %i[unit_id current]

    create_table :snapshot_people do |t|
      t.references :unit_snapshot, null: false, foreign_key: true
      t.references :person, foreign_key: true
      t.string :person_name
      t.string :part
      t.integer :sort_order, default: 0, null: false

      t.timestamps
    end

    add_index :snapshot_people, %i[unit_snapshot_id sort_order]
  end
end
