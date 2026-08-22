# frozen_string_literal: true

class AddActiveToSections < ActiveRecord::Migration[8.1]
  def change
    add_column :sections, :active, :boolean, null: false, default: true
  end
end
