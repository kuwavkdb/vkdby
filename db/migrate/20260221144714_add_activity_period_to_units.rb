class AddActivityPeriodToUnits < ActiveRecord::Migration[8.1]
  def change
    add_column :units, :activity_period, :jsonb
  end
end
