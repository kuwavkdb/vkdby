# frozen_string_literal: true

# 横断検索（SearchController）をpg_search（trigram戦略）に置き換えるにあたり、
# 新たに検索対象へ加わる custom_pages.title/body と sections.name に
# GINトライグラムインデックスを追加する（issue #1536）。
class AddTrgmIndexesToCustomPagesAndSections < ActiveRecord::Migration[8.1]
  def up
    add_index :custom_pages, :title, using: :gin, opclass: :gin_trgm_ops
    add_index :custom_pages, :body, using: :gin, opclass: :gin_trgm_ops
    add_index :sections, :name, using: :gin, opclass: :gin_trgm_ops
  end

  def down
    remove_index :sections, :name
    remove_index :custom_pages, :body
    remove_index :custom_pages, :title
  end
end
