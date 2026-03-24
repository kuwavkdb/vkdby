# frozen_string_literal: true

class CreateWikiPageImports < ActiveRecord::Migration[8.1]
  def change
    create_table :wiki_page_imports do |t|
      t.references :wikipage, null: false, foreign_key: true, index: { unique: true }
      t.string   :page_type
      t.datetime :last_imported_at
      t.string   :status, null: false, default: 'pending'
      t.string   :import_target_type
      t.bigint   :import_target_id
      t.text     :note
      t.timestamps
    end
  end
end
