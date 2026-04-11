# frozen_string_literal: true

class DropPersonLogs < ActiveRecord::Migration[8.1]
  def change
    drop_table :person_logs
  end
end
