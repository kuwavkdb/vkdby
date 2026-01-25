# frozen_string_literal: true

class CreatePersonLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :person_logs do |t|
      t.references :person, null: false, foreign_key: true
      t.integer :log_type
      t.references :unit, null: false, foreign_key: true
      t.integer :status

      t.timestamps
    end
  end
end
