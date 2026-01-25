# frozen_string_literal: true

class AddPartToPersonLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :person_logs, :part, :integer
  end
end
