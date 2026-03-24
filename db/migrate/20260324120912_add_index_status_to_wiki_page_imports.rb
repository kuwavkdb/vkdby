# frozen_string_literal: true

class AddIndexStatusToWikiPageImports < ActiveRecord::Migration[8.1]
  def change
    add_index :wiki_page_imports, :status
  end
end
