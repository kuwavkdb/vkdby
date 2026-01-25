# frozen_string_literal: true

class AddSnsAndInlineHistoryToUnitPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :unit_people, :sns, :string
    add_column :unit_people, :inline_history, :text
  end
end
