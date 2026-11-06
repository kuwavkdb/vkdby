# frozen_string_literal: true

# 動向に添付する画像（has_one_attached :image）の代替テキスト。任意入力で、空なら動向のタイトルを使う（issue #2014）
class AddImageAltToTrends < ActiveRecord::Migration[8.1]
  def change
    add_column :trends, :image_alt, :string
  end
end
