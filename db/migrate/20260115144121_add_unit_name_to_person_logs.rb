class AddUnitNameToPersonLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :person_logs, :unit_name, :string
  end
end
