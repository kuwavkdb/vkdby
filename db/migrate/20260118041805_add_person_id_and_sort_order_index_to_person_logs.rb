# frozen_string_literal: true

class AddPersonIdAndSortOrderIndexToPersonLogs < ActiveRecord::Migration[8.1]
  def change
    add_index :person_logs, %i[person_id sort_order]
  end
end
