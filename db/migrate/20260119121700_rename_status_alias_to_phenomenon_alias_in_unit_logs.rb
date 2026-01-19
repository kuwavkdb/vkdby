class RenameStatusAliasToPhenomenonAliasInUnitLogs < ActiveRecord::Migration[8.1]
  def change
    rename_column :unit_logs, :status_alias, :phenomenon_alias
  end
end
