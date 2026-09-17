# frozen_string_literal: true

class AddSubmitterIpToUnitSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :unit_submissions, :submitter_ip, :string
  end
end
