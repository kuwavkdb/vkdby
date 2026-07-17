# frozen_string_literal: true

class CreateOperationLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :operation_logs do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string :operation_type, null: false
      t.datetime :created_at, null: false
    end

    add_index :operation_logs, :operation_type
    add_index :operation_logs, :created_at
  end
end
