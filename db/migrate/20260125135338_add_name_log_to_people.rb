# frozen_string_literal: true

class AddNameLogToPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :name_log, :jsonb
  end
end
