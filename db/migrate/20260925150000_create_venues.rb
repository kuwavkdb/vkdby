# frozen_string_literal: true

# ライブハウス・ホールなどの会場（issue #1685, #1687）。
# 表記揺れ・改名・ネーミングライツに対応するため、Unit/Personと同じ形のname_log/aliasesを持つ。
# name/name_log/aliasesのtrgmインデックスは、管理画面の検索と、後続のTrendとの紐付け
# （既存Trendのタイトル・本文からの突き合わせ、会場入力欄のサジェスト）で使う。
class CreateVenues < ActiveRecord::Migration[8.1]
  def change
    create_table :venues do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.string :name_kana
      t.jsonb :name_log, null: false, default: []
      t.jsonb :aliases, null: false, default: []
      t.integer :venue_type, null: false, default: 0
      t.string :prefecture
      t.string :area
      t.string :address
      t.integer :capacity
      t.integer :status, null: false, default: 1
      t.text :note
      t.string :old_key
      t.integer :old_wiki_id
      t.text :old_wiki_text
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :venues, :key, unique: true
    add_index :venues, :old_key, unique: true
    add_index :venues, :discarded_at
    add_index :venues, :prefecture
    add_index :venues, :venue_type
    add_index :venues, :name, using: :gin, opclass: :gin_trgm_ops
    add_index :venues, '(name_log::text) gin_trgm_ops', using: :gin, name: 'index_venues_on_name_log_trgm'
    add_index :venues, '(aliases::text) gin_trgm_ops', using: :gin, name: 'index_venues_on_aliases_trgm'
  end
end
