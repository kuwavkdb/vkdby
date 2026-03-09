# frozen_string_literal: true

class AddDiscardedAtToSnapshotPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :snapshot_people, :discarded_at, :datetime
    add_index :snapshot_people, :discarded_at
  end
end
