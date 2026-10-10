# frozen_string_literal: true

require 'test_helper'

class OutboundLinksControllerTest < ActionDispatch::IntegrationTest
  def create_item(link_url:, asin: nil)
    Item.create!(title: 'Cushion Item', release_date: '2026-03-01', asin: asin, link_url: link_url)
  end

  test '販売サイトへのクッションページを表示する' do
    item = create_item(link_url: 'https://www.example-shop.jp/items/123')

    get item_outbound_path(item)

    assert_response :success
    assert_select 'a[href=?][rel~=nofollow]', 'https://www.example-shop.jp/items/123', text: /example-shop\.jp へ進む/
    assert_select 'meta[name=robots][content*=noindex]'
    assert_includes response.body, 'Cushion Item'
  end

  test 'クッションページではAdSenseを読み込まない' do
    item = create_item(link_url: 'https://www.example-shop.jp/items/123')
    original = ENV.fetch('GOOGLE_ADSENSE_CLIENT_ID', nil)
    ENV['GOOGLE_ADSENSE_CLIENT_ID'] = 'ca-pub-0000000000000000'

    get item_outbound_path(item)

    assert_response :success
    assert_not_includes response.body, 'adsbygoogle'
  ensure
    ENV['GOOGLE_ADSENSE_CLIENT_ID'] = original
  end

  test 'クエリパラメータで遷移先を差し替えられない' do
    item = create_item(link_url: 'https://www.example-shop.jp/items/123')

    get item_outbound_path(item, url: 'https://evil.example/')

    assert_response :success
    # og:url やログインリンクの return_to にはリクエストURLがエスケープされて入るので、リンク先だけを確かめる
    assert_select 'a[href^="https://evil.example"]', count: 0
    assert_select 'a[href=?]', 'https://www.example-shop.jp/items/123'
  end

  test '遷移先が http / https 以外なら404' do
    item = create_item(link_url: 'javascript:alert(1)')

    get item_outbound_path(item)

    assert_response :not_found
  end

  test '遷移先のURLにHTMLを埋め込めない' do
    item = create_item(link_url: 'https://www.example-shop.jp/items/"><script>alert(1)</script>')

    get item_outbound_path(item)

    assert_response :not_found
    assert_not_includes response.body, '<script>alert(1)</script>'
  end

  test '削除済みのアイテムは404' do
    item = create_item(link_url: 'https://www.example-shop.jp/items/123')
    item.discard

    get item_outbound_path(item)

    assert_response :not_found
  end
end
