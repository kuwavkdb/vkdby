# frozen_string_literal: true

require 'test_helper'

# Trend詳細ページの会場名表示（issue #1689）
class TrendVenueDisplayTest < ActionDispatch::IntegrationTest
  test 'show displays the venue name on the trend date with a link to the venue page' do
    venue = Venue.create!(key: 'shinjuku-loft', name: '新宿LOFT',
                          name_log: [{ 'name' => '旧LOFT', 'date' => '1976' }, { 'name' => '新宿LOFT', 'date' => '1999' }])
    trend = Trend.create!(title: 'ワンマン', date: Date.new(1990, 1, 1), publish_start_at: Time.current,
                          unit_phenomenon: :live, venue: venue)

    get trend_path(trend)

    assert_response :success
    assert_select 'span', text: /旧LOFT/
    assert_select "a[href='#{venue_path('shinjuku-loft')}']", text: '旧LOFT'
    assert_not_includes response.body, '新宿LOFT'
  end

  test 'show displays the overridden venue name without a link when the venue is discarded' do
    venue = Venue.create!(key: 'closed-venue', name: '閉店した会場')
    venue.discard
    trend = Trend.create!(title: 'ライブ', date: Date.current, publish_start_at: Time.current,
                          unit_phenomenon: :live, venue: venue, venue_name: '上書きした会場名')

    get trend_path(trend)

    assert_response :success
    assert_includes response.body, '上書きした会場名'
    assert_select "a[href='#{venue_path('closed-venue')}']", count: 0
  end

  test 'show does not render a venue section when no venue is set' do
    trend = Trend.create!(title: '会場なし', date: Date.current, publish_start_at: Time.current, unit_phenomenon: :live)

    get trend_path(trend)

    assert_response :success
    assert_not_includes response.body, '会場:'
  end
end
