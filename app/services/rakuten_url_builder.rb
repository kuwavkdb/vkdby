# frozen_string_literal: true

# 楽天市場の検索結果ページへの、楽天アフィリエイトのリンクを組み立てるサービス（issue #2057）
# AmazonUrlBuilder にならい、アフィリエイトIDは config.rakuten_link_affiliate_id から読む。
# 形式は楽天の管理画面「リンク作成」のリンクに合わせる（画像付きリンクの見た目を表す link_type・ut は付けない）
class RakutenUrlBuilder
  AFFILIATE_BASE_URL = 'https://hb.afl.rakuten.co.jp/ichiba'
  SEARCH_BASE_URL = 'https://search.rakuten.co.jp/search/mall'

  def self.search(keyword)
    return nil if keyword.blank?

    "#{AFFILIATE_BASE_URL}/#{Rails.application.config.rakuten_link_affiliate_id}/?pc=#{ERB::Util.url_encode(search_url(keyword))}"
  end

  # 楽天市場の検索結果ページのURL。検索語はURLのパスに入るため、パスの区切りになる「/」は空白に置き換える
  def self.search_url(keyword)
    "#{SEARCH_BASE_URL}/#{ERB::Util.url_encode(keyword.tr('/', ' ').squish)}/"
  end
end
