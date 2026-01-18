class AddPersonIdAndSortOrderIndexToPersonLogs < ActiveRecord::Migration[8.1]
  def change
    add_index :person_logs, [ :person_id, :sort_order ]
  end
end
