# frozen_string_literal: true

class ChangeTextColumnTypeInLogs < ActiveRecord::Migration[8.1]
  def up
    change_column :person_logs, :text, :text
    change_column :unit_logs, :text, :text
  end

  def down
    change_column :person_logs, :text, :string
    change_column :unit_logs, :text, :string
  end
end
