class CreatePeople < ActiveRecord::Migration[8.1]
  def change
    create_table :people do |t|
      t.string :name
      t.string :name_kana
      t.date :birthday
      t.string :blood
      t.string :hometown
      t.integer :status

      t.timestamps
    end
  end
end
