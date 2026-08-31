# frozen_string_literal: true

# ASINからAmazonアソシエイトタグ付きの商品URLを組み立てるサービス
# ItemConverter（新規アイテム作成時）と Item#display_link_url（出力時のタグ補完、issue #1304）の
# 両方から利用する
class AmazonUrlBuilder
  def self.build(asin)
    return nil if asin.blank?

    "https://www.amazon.co.jp/exec/obidos/ASIN/#{asin}/#{Rails.application.config.amazon_associate_tag}/"
  end
end
