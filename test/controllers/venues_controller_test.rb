# frozen_string_literal: true

require 'test_helper'

# 会場の公開ページ（issue #1691）
class VenuesControllerTest < ActionDispatch::IntegrationTest
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

  test 'index lists kept venues' do
    discarded = Venue.create!(key: 'gone', name: '削除済み会場')
    discarded.discard

    get venues_path

    assert_response :success
    assert_select "a[href='#{venue_path(@loft.key)}']", text: '新宿LOFT'
    assert_select "a[href='#{venue_path(@hall.key)}']"
    assert_select "a[href='#{venue_path(@osaka.key)}']"
    assert_not_includes response.body, '削除済み会場'
  end

  test 'index filters by prefecture and area' do
    get venues_path(prefecture: '東京都')

    assert_response :success
    assert_select "a[href='#{venue_path(@loft.key)}']"
    assert_select "a[href='#{venue_path(@hall.key)}']"
    assert_select "a[href='#{venue_path(@osaka.key)}']", count: 0

    get venues_path(prefecture: '東京都', area: '新宿')

    assert_select "a[href='#{venue_path(@loft.key)}']"
    assert_select "a[href='#{venue_path(@hall.key)}']", count: 0
  end

  test 'index filters by venue type' do
    get venues_path(venue_type: 'hall')

    assert_response :success
    assert_select "a[href='#{venue_path(@hall.key)}']"
    assert_select "a[href='#{venue_path(@loft.key)}']", count: 0
  end

  test 'index ignores unknown filter values' do
    get venues_path(prefecture: '存在しない県', venue_type: 'unknown')

    assert_response :success
    assert_select "a[href='#{venue_path(@osaka.key)}']"
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
    assert_select 'h1', text: '新宿LOFT'
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
