# frozen_string_literal: true

class AddStatusAliasToPersonLogsAndUnitLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :person_logs, :status_alias, :string
    add_column :unit_logs, :status_alias, :string
  end
end
