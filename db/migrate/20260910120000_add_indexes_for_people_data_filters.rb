# frozen_string_literal: true

class AddIndexesForPeopleDataFilters < ActiveRecord::Migration[8.1]
  def up
    add_index :people, :blood
    add_index :people, :hometown

    # parts@>での絞り込み（issue #1453）を高速化するため json -> jsonb に変更し GIN インデックスを追加する
    change_column :people, :parts, :jsonb, using: 'parts::jsonb'
    add_index :people, :parts, using: :gin
  end

  def down
    remove_index :people, :parts
    change_column :people, :parts, :json, using: 'parts::json'

    remove_index :people, :hometown
    remove_index :people, :blood
  end
end
