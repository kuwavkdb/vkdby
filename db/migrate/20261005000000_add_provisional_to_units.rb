# frozen_string_literal: true

# 簡単登録で作成した「仮登録」のユニットを一般ユーザーに表示しないためのフラグ（issue #1764）
class AddProvisionalToUnits < ActiveRecord::Migration[8.1]
  def change
    add_column :units, :provisional, :boolean, default: false, null: false
    add_index :units, :provisional, where: 'provisional = TRUE'
  end
end
