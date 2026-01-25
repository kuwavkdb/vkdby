# frozen_string_literal: true

class AddSourceUrlAndQuoteTextToLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :person_logs, :source_url, :string
    add_column :person_logs, :quote_text, :text
    add_column :unit_logs, :source_url, :string
    add_column :unit_logs, :quote_text, :text
  end
end
