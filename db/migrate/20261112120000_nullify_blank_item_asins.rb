# frozen_string_literal: true

# 空文字のASINをNULLに直す。空文字どうしは一意インデックス（index_items_on_asin）で
# 重複とみなされ、ASINなしのアイテムを2件以上保存できなかったため（issue #2040）
class NullifyBlankItemAsins < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE items SET asin = NULL WHERE btrim(asin) = ''"
  end

  def down
    # NULLに直したデータは元の空文字と区別できないため戻さない
  end
end
