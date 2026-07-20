# frozen_string_literal: true

class AddVariousArtistsToItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :various_artists, :boolean, default: false, null: false
  end
end
