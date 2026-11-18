# frozen_string_literal: true

require 'test_helper'

class RakutenUrlBuilderTest < ActiveSupport::TestCase
  test '検索語から楽天市場の検索結果へのアフィリエイトリンクを組み立てる' do
    affiliate_id = Rails.application.config.rakuten_link_affiliate_id
    search_url = 'https://search.rakuten.co.jp/search/mall/%E3%83%90%E3%83%B3%E3%83%89%20Album/'

    assert_equal "https://hb.afl.rakuten.co.jp/ichiba/#{affiliate_id}/?pc=#{ERB::Util.url_encode(search_url)}",
                 RakutenUrlBuilder.search('バンド Album')
  end

  test '検索語の「/」は検索結果URLのパスを区切らないよう空白にする' do
    assert_equal 'https://search.rakuten.co.jp/search/mall/A%20B/', RakutenUrlBuilder.search_url('A / B')
  end

  test '検索語が空なら nil' do
    assert_nil RakutenUrlBuilder.search('')
    assert_nil RakutenUrlBuilder.search(nil)
  end
end
