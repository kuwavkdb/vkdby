# frozen_string_literal: true

class CreateUpdateLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :update_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false
      t.string :loggable_type, null: false
      t.bigint :loggable_id, null: false
      t.jsonb :diff

      t.datetime :created_at, null: false
    end

    add_index :update_logs, %i[loggable_type loggable_id]
    add_index :update_logs, :created_at
  end
end
