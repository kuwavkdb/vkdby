# frozen_string_literal: true

require 'test_helper'

# 会場一覧のテーブル表示（issue #1783）
class VenueIndexTableTest < ActionDispatch::IntegrationTest
  test 'index lists venues in a table without the kana reading' do
    venue = Venue.create!(key: 'shinjuku-loft', name: '新宿LOFT', name_kana: 'しんじゅくろふと',
                          prefecture: '東京都', area: '新宿', capacity: 550, status: :closed)

    get venues_path

    assert_response :success
    assert_select 'table thead th', text: '会場名'
    assert_select 'table tbody tr', count: 1 do
      assert_select "th[scope='row'] a[href='#{venue_path(venue.key)}']", text: '新宿LOFT'
      assert_select 'th', text: /閉店/
      assert_select 'td', text: 'ライブハウス'
      assert_select 'td', text: '東京都 新宿'
      assert_select 'td', text: '550'
    end
    assert_not_includes response.body, 'しんじゅくろふと'
  end

  test 'index shows the trend count column only to logged-in users' do
    venue = Venue.create!(key: 'shinjuku-loft', name: '新宿LOFT')
    Trend.create!(title: 'ライブ', date: Date.new(2020, 1, 1), publish_start_at: 1.day.ago,
                  unit_phenomenon: :live, venue: venue)

    get venues_path

    assert_select 'table thead th', text: '動向', count: 0
    assert_select 'table tbody td', count: 3

    post login_path, params: { email: users(:one).email, password: 'password' }
    get venues_path

    assert_select 'table thead th', text: '動向'
    assert_select 'table tbody td', text: '1'
  end
end
