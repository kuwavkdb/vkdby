class AddOldHistoryToPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :old_history, :text
  end
end
