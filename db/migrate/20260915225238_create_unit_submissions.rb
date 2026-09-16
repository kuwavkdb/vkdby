# frozen_string_literal: true

class CreateUnitSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :unit_submissions do |t|
      t.string :name, null: false
      t.string :name_kana
      t.integer :unit_type
      t.integer :status
      t.integer :submission_status, null: false, default: 0
      t.text :note
      t.string :email
      t.boolean :is_related_person, null: false, default: false
      t.bigint :converted_unit_id

      t.timestamps
    end

    add_index :unit_submissions, :submission_status
    add_index :unit_submissions, :converted_unit_id
    add_foreign_key :unit_submissions, :units, column: :converted_unit_id
  end
end
