# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :name
      t.string :uid, null: false
      t.string :provider, null: false
      t.integer :role, default: 0, null: false

      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, %i[uid provider], unique: true
  end
end
