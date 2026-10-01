# frozen_string_literal: true

class AddImageUsageConsentedToUnitSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :unit_submissions, :image_usage_consented, :boolean, default: false, null: false
  end
end
