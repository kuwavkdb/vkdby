# frozen_string_literal: true

# units/peopleの検索（横断検索・索引ページ・入力補完API）はname_log/aliasesの
# jsonbカラムをtextにキャストしてILIKE検索しているが、対応するインデックスが
# なくSeq Scanになっていた。入力補完APIはキー入力ごとに呼ばれるため、
# 索引ページ・横断検索と合わせて負荷が大きい（EXPLAIN ANALYZEで
# 50000件のunitsに対しSeq Scan約86ms→trgmインデックス追加後は
# Bitmap Heap Scanで約0.2msまで短縮することを確認済み）。
# items.artistsで既に採用しているのと同じ手法（式インデックス）で対応する。
class AddTrgmIndexesToUnitsAndPeopleJsonColumns < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  INDEXES = [
    %w[units name_log index_units_on_name_log_trgm],
    %w[units aliases index_units_on_aliases_trgm],
    %w[people name_log index_people_on_name_log_trgm],
    %w[people aliases index_people_on_aliases_trgm]
  ].freeze

  def up
    INDEXES.each do |table, column, index_name|
      next if index_exists?(table, nil, name: index_name)

      execute <<~SQL.squish
        CREATE INDEX CONCURRENTLY #{index_name} ON #{table} USING gin ((#{column}::text) gin_trgm_ops)
      SQL
    end
  end

  def down
    INDEXES.each do |_table, _column, index_name|
      execute "DROP INDEX CONCURRENTLY IF EXISTS #{index_name}"
    end
  end
end
