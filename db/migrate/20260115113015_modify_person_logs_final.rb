class ModifyPersonLogsFinal < ActiveRecord::Migration[8.1]
  def change
    add_column :person_logs, :name, :string
    add_column :person_logs, :log_date, :string
    add_column :person_logs, :sort_order, :integer
    change_column_null :person_logs, :status, false
    change_column_null :person_logs, :unit_id, true
  end
end
