class CreateCustomPageIncludes < ActiveRecord::Migration[8.1]
  def change
    create_table :custom_page_includes do |t|
      t.references :source_custom_page, null: false, foreign_key: { to_table: :custom_pages }
      t.references :target_custom_page, null: false, foreign_key: { to_table: :custom_pages }
      t.string :section_name, null: false

      t.timestamps
    end
  end
end
