# frozen_string_literal: true

class CreateSections < ActiveRecord::Migration[8.1]
  def change
    create_table :sections do |t|
      t.string :name
      t.text :wiki_text
      t.integer :sort_order
      t.references :sectionable, polymorphic: true, null: false

      t.timestamps
    end
  end
end
