# frozen_string_literal: true

require 'test_helper'

# 会場ページの地図表示（issue #1781）
class VenueMapTest < ActionDispatch::IntegrationTest
  test 'show embeds a Google map above the address for a venue with an address' do
    venue = Venue.create!(key: 'shinjuku-loft', name: '新宿LOFT', address: '東京都新宿区歌舞伎町1-12-9')

    get venue_path(venue.key)

    assert_response :success
    query = URI.encode_www_form_component('東京都新宿区歌舞伎町1-12-9')
    assert_select "iframe[title='新宿LOFTの地図'][loading='lazy']" do |iframes|
      assert_equal "https://www.google.com/maps?q=#{query}&output=embed", iframes.first['src']
    end
    assert_operator response.body.index('<iframe'), :<, response.body.index('>住所</dt>'), '地図は住所の上に表示する'
  end

  test 'show does not render a map for a venue without an address' do
    venue = Venue.create!(key: 'no-address', name: '住所なし', prefecture: '東京都', area: '新宿')

    get venue_path(venue.key)

    assert_response :success
    assert_select 'iframe', count: 0
  end

  test 'show strips the legacy MAP: prefix from the address and the map query' do
    venue = Venue.create!(key: 'legacy-address', name: '旧住所', address: 'MAP:東京都新宿区歌舞伎町1-12-9')

    get venue_path(venue.key)

    assert_response :success
    query = URI.encode_www_form_component('東京都新宿区歌舞伎町1-12-9')
    assert_select "iframe[src='https://www.google.com/maps?q=#{query}&output=embed']"
    assert_select 'dd', text: '東京都新宿区歌舞伎町1-12-9'
    assert_not_includes response.body, 'MAP:'
  end

  test 'show does not render a map for a streaming venue' do
    venue = Venue.create!(key: 'streaming', name: '配信', venue_type: :streaming, address: '東京都渋谷区')

    get venue_path(venue.key)

    assert_response :success
    assert_select 'iframe', count: 0
  end

  test 'show notes that a closed venue may now be a different facility' do
    venue = Venue.create!(key: 'closed', name: '閉店した会場', status: :closed, address: '東京都新宿区')

    get venue_path(venue.key)

    assert_response :success
    assert_select 'iframe', count: 1
    assert_includes response.body, '閉店した会場のため'
  end
end
