class AddIndexOldHistoryToPeople < ActiveRecord::Migration[8.1]
  def change
    add_index :people, :old_history, using: :gin, opclass: :gin_trgm_ops
  end
end
