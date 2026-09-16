# frozen_string_literal: true

class CreateTrendSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :trend_submissions do |t|
      t.integer :target_type, null: false
      t.bigint :target_id
      t.string :target_name, null: false
      t.date :date, null: false
      t.boolean :day_unknown, null: false, default: false
      t.boolean :month_unknown, null: false, default: false
      t.string :title
      t.text :content
      t.string :via_url, null: false
      t.integer :phenomenon, null: false
      t.string :email
      t.boolean :is_related_person, null: false, default: false
      t.integer :submission_status, null: false, default: 0
      t.string :submitter_ip
      t.bigint :converted_trend_id

      t.timestamps
    end

    add_index :trend_submissions, :submission_status
    add_index :trend_submissions, :converted_trend_id
    add_foreign_key :trend_submissions, :trends, column: :converted_trend_id
  end
end
