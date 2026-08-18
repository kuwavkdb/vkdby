# frozen_string_literal: true

class CreateTemporarySnapshotPeople < ActiveRecord::Migration[8.1]
  def change
    create_table :temporary_snapshot_people do |t|
      t.bigint  :person_id
      t.string  :person_key
      t.string  :person_name
      t.string  :name_alias
      t.integer :part, null: false, default: 0
      t.string  :part_alias
      t.boolean :support, null: false, default: false
      t.integer :status, null: false, default: 1
      t.string  :old_person_key
      t.json    :sns
      t.text    :inline_history
      t.bigint  :hint_unit_id
      t.string  :source, null: false, default: 'career_history_import'

      t.timestamps
    end

    add_index :temporary_snapshot_people, :person_id
    add_index :temporary_snapshot_people, :person_key
    add_index :temporary_snapshot_people, :old_person_key
    add_index :temporary_snapshot_people, :hint_unit_id

    add_foreign_key :temporary_snapshot_people, :people
    add_foreign_key :temporary_snapshot_people, :units, column: :hint_unit_id
  end
end
