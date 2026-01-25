# frozen_string_literal: true

class ChangeSnsToJsonInUnitPeople < ActiveRecord::Migration[8.1]
  def up
    # Add temporary json column
    add_column :unit_people, :sns_json, :json

    # Migrate existing string data to json array format
    UnitPerson.reset_column_information
    UnitPerson.find_each do |up|
      up.update_column(:sns_json, [up.sns]) if up.sns.present?
    end

    # Remove old string column and rename json column
    remove_column :unit_people, :sns
    rename_column :unit_people, :sns_json, :sns
  end

  def down
    # Add temporary string column
    add_column :unit_people, :sns_string, :string

    # Migrate json data back to string (take first element)
    UnitPerson.reset_column_information
    UnitPerson.find_each do |up|
      up.update_column(:sns_string, up.sns.first) if up.sns.present? && up.sns.is_a?(Array)
    end

    # Remove json column and rename string column
    remove_column :unit_people, :sns
    rename_column :unit_people, :sns_string, :sns
  end
end
