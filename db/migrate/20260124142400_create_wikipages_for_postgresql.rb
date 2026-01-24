class CreateWikipagesForPostgresql < ActiveRecord::Migration[8.1]
  def change
    create_table :wikipages do |t|
      t.string :name, null: false
      t.string :title, limit: 100
      t.text :wiki
      t.string :category
      t.integer :level, limit: 2, default: 0, null: false
      t.string :ip, limit: 64
      t.integer :dw_id
      t.string :it_id, limit: 12
      t.string :pia_id, limit: 12
      t.integer :eplus_id
      
      t.timestamps precision: nil
    end
    
    add_index :wikipages, :name, unique: true
    
    # Enable pg_trgm extension for full-text search
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"
    
    # Add GIN index for full-text search on wiki column
    add_index :wikipages, :wiki, using: :gin, opclass: :gin_trgm_ops, name: "index_wikipages_on_wiki_gin"
  end
end
