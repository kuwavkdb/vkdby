# frozen_string_literal: true

class AddActiveToTagIndices < ActiveRecord::Migration[8.1]
  def change
    add_column :tag_indices, :active, :boolean, default: true, null: false
  end
end
