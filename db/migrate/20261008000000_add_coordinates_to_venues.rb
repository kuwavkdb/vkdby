# frozen_string_literal: true

# 都道府県・エリアページの地図に会場をプロットするための座標（issue #1801）。
# 座標は世界測地系の10進数の度。coordinates_sourceは取得元（自動取得 / 管理画面での手入力）で、
# 手入力した座標を住所変更時の自動取得で上書きしないために区別する
class AddCoordinatesToVenues < ActiveRecord::Migration[8.1]
  def change
    change_table :venues, bulk: true do |t|
      t.decimal :latitude, precision: 9, scale: 6
      t.decimal :longitude, precision: 9, scale: 6
      t.integer :coordinates_source
    end
  end
end
