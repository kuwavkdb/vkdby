class RenameColumnsInPersonLogs < ActiveRecord::Migration[8.1]
  def change
    rename_column :person_logs, :status, :phenomenon
    rename_column :person_logs, :status_alias, :phenomenon_alias
  end
end
