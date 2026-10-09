# frozen_string_literal: true

require 'test_helper'

# 会場の公開ページ（issue #1691）
class VenuesControllerTest < ActionDispatch::IntegrationTest # rubocop:disable Metrics/ClassLength
  setup do
    @loft = Venue.create!(key: 'shinjuku-loft', name: '新宿LOFT', name_kana: 'しんじゅくろふと',
                          prefecture: '東京都', area: '新宿', venue_type: :live_house, capacity: 550,
                          address: '東京都新宿区歌舞伎町1-12-9',
                          name_log: [{ 'name' => '旧LOFT', 'date' => '1976' }, { 'name' => '新宿LOFT', 'date' => '1999' }],
                          aliases: [{ 'name' => 'LOFT' }, { 'name' => '非表示の別名', 'hidden' => true }])
    @hall = Venue.create!(key: 'nippon-budokan', name: '日本武道館', prefecture: '東京都', area: '九段下',
                          venue_type: :hall)
    @osaka = Venue.create!(key: 'osaka-muse', name: '心斎橋MUSE', prefecture: '大阪府', area: '心斎橋',
                           venue_type: :live_house)
  end

  test 'index lists prefectures by region with venue counts' do
    Venue.create!(key: 'gone', name: '削除済み会場', prefecture: '北海道').discard

    get venues_path

    assert_response :success
    assert_select 'h1', text: /3 records/
    assert_select "nav[aria-label='都道府県から会場を探す'] h2", text: '関東'
    assert_select "nav[aria-label='都道府県から会場を探す'] h2", text: '近畿'
    assert_select "a[href='#{venue_prefecture_path('東京都')}']", text: /東京都\s*2/
    assert_select "a[href='#{venue_prefecture_path('大阪府')}']", text: /大阪府\s*1/
    assert_not_includes response.body, '削除済み会場'
    assert_select 'input[type=search]', count: 0
    assert_select 'table', count: 0
  end

  test 'index shows prefectures without venues as text, not links' do
    get venues_path

    assert_select "a[href='#{venue_prefecture_path('北海道')}']", count: 0
    assert_select 'li span', text: /北海道\s*0/
  end

  test 'index links to the list of venues without a prefecture' do
    Venue.create!(key: 'somewhere', name: '都道府県のない会場')

    get venues_path

    assert_select "a[href='#{venue_prefecture_path(Venue::UNASSIGNED_PREFECTURE)}']", text: /都道府県未設定\s*1/
  end

  test 'index redirects legacy prefecture and area filters to the area pages' do
    get venues_path(prefecture: '東京都')
    assert_redirected_to venue_prefecture_path('東京都')
    assert_response :moved_permanently

    get venues_path(prefecture: '東京都', area: '新宿')
    assert_redirected_to venue_area_path('東京都', '新宿')

    get venues_path(prefecture: '東京都', area: '存在しないエリア')
    assert_redirected_to venue_prefecture_path('東京都')

    get venues_path(prefecture: '東京都', venue_type: 'hall', page: '2')
    assert_redirected_to venue_prefecture_path('東京都', venue_type: 'hall')
  end

  test 'index redirects other legacy queries to the prefecture list' do
    get venues_path(q: '武道館')
    assert_redirected_to venues_path
    assert_response :moved_permanently

    get venues_path(venue_type: 'hall')
    assert_redirected_to venues_path

    get venues_path(prefecture: '存在しない県')
    assert_redirected_to venues_path

    get venues_path(prefecture: '北海道')
    assert_redirected_to venues_path
  end

  test 'show links the venue type to the prefecture page filtered by the type' do
    get venue_path(@hall.key)

    assert_select "a[href='#{venue_prefecture_path('東京都', venue_type: 'hall')}']", text: 'ホール'
  end

  test 'show links the venue type of a venue without a prefecture to the unassigned list' do
    venue = Venue.create!(key: 'somewhere', name: '都道府県のない会場', venue_type: :hall)

    get venue_path(venue.key)

    assert_select "a[href='#{venue_prefecture_path(Venue::UNASSIGNED_PREFECTURE, venue_type: 'hall')}']", text: 'ホール'
  end

  test 'show displays venue details and published trends in date descending order' do
    old_trend = Trend.create!(title: '古いライブ', date: Date.new(2001, 1, 1), publish_start_at: 1.day.ago,
                              unit_phenomenon: :live, venue: @loft)
    new_trend = Trend.create!(title: '新しいライブ', date: Date.new(2020, 1, 1), publish_start_at: 1.day.ago,
                              unit_phenomenon: :live, venue: @loft)
    Trend.create!(title: '非公開のライブ', date: Date.new(2010, 1, 1), publish_start_at: 1.day.ago, active: false,
                  unit_phenomenon: :live, venue: @loft)
    Trend.create!(title: '別会場のライブ', date: Date.new(2010, 1, 1), publish_start_at: 1.day.ago,
                  unit_phenomenon: :live, venue: @hall)

    get venue_path(@loft.key)

    assert_response :success
    assert_select 'header h1', text: /新宿LOFT/
    assert_select 'header', text: %r{/\s*LOFT}
    assert_includes response.body, '東京都新宿区歌舞伎町1-12-9'
    assert_includes response.body, '550'
    assert_includes response.body, '旧LOFT'
    assert_includes response.body, 'LOFT'
    assert_not_includes response.body, '非表示の別名'
    assert_not_includes response.body, '非公開のライブ'
    assert_not_includes response.body, '別会場のライブ'

    trend_links = css_select("a[href^='/trends/']").map { |a| a['href'] }
    assert_equal [trend_path(new_trend), trend_path(old_trend)], trend_links
  end

  test 'show includes trends of venues merged into this venue' do
    merged = Venue.create!(key: 'loft-old', name: '旧ロフト', destination_key: @loft.key)
    merged.discard
    Trend.create!(title: '統合元のライブ', date: Date.new(1990, 1, 1), publish_start_at: 1.day.ago,
                  unit_phenomenon: :live, venue: merged)

    get venue_path(@loft.key)

    assert_response :success
    assert_includes response.body, '統合元のライブ'
  end

  test 'show redirects a key-changed venue to its new key' do
    @loft.change_key!('shinjuku-loft-2')

    get venue_path('shinjuku-loft')

    assert_response :moved_permanently
    assert_redirected_to venue_path('shinjuku-loft-2')
  end

  test 'show returns 404 for a discarded venue' do
    @loft.discard

    get venue_path(@loft.key)

    assert_response :not_found
  end

  test 'show returns 404 for an unknown key' do
    get venue_path('no-such-venue')

    assert_response :not_found
  end
end
