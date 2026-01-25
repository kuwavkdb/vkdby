# frozen_string_literal: true

class AddTextToPersonLogsAndUnitLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :person_logs, :text, :string
    add_column :unit_logs, :text, :string
  end
end
