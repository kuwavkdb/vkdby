# frozen_string_literal: true

# 動向の本文の下に出す画像（has_one_attached :bottom_image）の代替テキスト。任意入力で、空なら動向のタイトルを使う（issue #2014）
class AddBottomImageAltToTrends < ActiveRecord::Migration[8.1]
  def change
    add_column :trends, :bottom_image_alt, :string
  end
end
