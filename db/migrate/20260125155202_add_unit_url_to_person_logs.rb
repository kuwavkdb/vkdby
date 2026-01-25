# frozen_string_literal: true

class AddUnitUrlToPersonLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :person_logs, :unit_url, :string
  end
end
