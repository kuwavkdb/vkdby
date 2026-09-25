# frozen_string_literal: true

# 会場のキー変更・統合時の転送先（issue #1687）。Unit/Personと同じく、キー変更時に旧キーの
# スタブレコード（論理削除済み・destination_keyに新キー）を残し、旧キーへのアクセスを転送する。
class AddDestinationKeyToVenues < ActiveRecord::Migration[8.1]
  def change
    add_column :venues, :destination_key, :string
    add_index :venues, :destination_key, where: 'destination_key IS NOT NULL'
  end
end
