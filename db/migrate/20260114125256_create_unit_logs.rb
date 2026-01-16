class CreateUnitLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :unit_logs do |t|
      t.references :unit, null: false, foreign_key: true
      t.date :date
      t.integer :phenomenon

      t.timestamps
    end
  end
end
