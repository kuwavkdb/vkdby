class AddDiscardedAtToSections < ActiveRecord::Migration[8.1]
  def change
    add_column :sections, :discarded_at, :datetime
    add_index :sections, :discarded_at
  end
end
