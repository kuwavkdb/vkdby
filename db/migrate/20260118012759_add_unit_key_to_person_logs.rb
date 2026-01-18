class AddUnitKeyToPersonLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :person_logs, :unit_key, :string
  end
end
