class AddManuallySetToWikiPageImports < ActiveRecord::Migration[8.1]
  def change
    add_column :wiki_page_imports, :manually_set, :boolean, default: false, null: false
  end
end
