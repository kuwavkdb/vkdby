# frozen_string_literal: true

class AddDiscardedAtToPeopleAndUnits < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :discarded_at, :datetime
    add_index :people, :discarded_at

    add_column :units, :discarded_at, :datetime
    add_index :units, :discarded_at
  end
end
