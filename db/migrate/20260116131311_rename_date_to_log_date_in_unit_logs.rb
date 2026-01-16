class RenameDateToLogDateInUnitLogs < ActiveRecord::Migration[8.1]
  def change
    rename_column :unit_logs, :date, :log_date
  end
end
