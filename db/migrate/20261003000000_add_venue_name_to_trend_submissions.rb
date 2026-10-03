# frozen_string_literal: true

class AddVenueNameToTrendSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :trend_submissions, :venue_name, :string
  end
end
