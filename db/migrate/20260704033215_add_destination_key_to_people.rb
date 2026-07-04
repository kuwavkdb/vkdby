# frozen_string_literal: true

class AddDestinationKeyToPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :destination_key, :string
  end
end
