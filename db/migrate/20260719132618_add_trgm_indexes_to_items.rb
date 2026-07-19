# frozen_string_literal: true

class AddTrgmIndexesToItems < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    unless index_exists?(:items, :title, name: 'index_items_on_title_trgm')
      add_index :items, :title, using: :gin, opclass: :gin_trgm_ops, name: 'index_items_on_title_trgm', algorithm: :concurrently
    end

    return if index_exists?(:items, nil, name: 'index_items_on_artists_trgm')

    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY index_items_on_artists_trgm ON items USING gin ((artists::text) gin_trgm_ops)
    SQL
  end

  def down
    remove_index :items, name: 'index_items_on_title_trgm', algorithm: :concurrently, if_exists: true
    execute 'DROP INDEX CONCURRENTLY IF EXISTS index_items_on_artists_trgm'
  end
end
