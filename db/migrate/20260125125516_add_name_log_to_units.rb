class AddNameLogToUnits < ActiveRecord::Migration[8.1]
  def change
    add_column :units, :name_log, :jsonb
  end
end
