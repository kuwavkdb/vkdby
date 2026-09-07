# frozen_string_literal: true

class AddPersonNameInTitleToTrends < ActiveRecord::Migration[8.1]
  def change
    add_column :trends, :person_name_in_title, :boolean, default: false, null: false
  end
end
