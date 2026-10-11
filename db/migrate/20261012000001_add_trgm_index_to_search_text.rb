# frozen_string_literal: true

# search_text の部分一致（LIKE）を trigram index で引けるようにする（issue #1842）。
# 作成中に表への書き込みを止めないよう CONCURRENTLY で作る。
class AddTrgmIndexToSearchText < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  TABLES = %i[units people venues].freeze

  def change
    TABLES.each do |table|
      add_index table, :search_text, using: :gin, opclass: :gin_trgm_ops,
                                     name: "index_#{table}_on_search_text_trgm",
                                     algorithm: :concurrently, if_not_exists: true
    end
  end
end
