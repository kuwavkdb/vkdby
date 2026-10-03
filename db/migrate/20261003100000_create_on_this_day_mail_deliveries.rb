# frozen_string_literal: true

class CreateOnThisDayMailDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :on_this_day_mail_deliveries do |t|
      t.date :date, null: false
      t.text :body, null: false
      t.timestamps
    end
    add_index :on_this_day_mail_deliveries, :date, unique: true
  end
end
