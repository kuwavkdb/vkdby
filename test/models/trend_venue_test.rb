# frozen_string_literal: true

require 'test_helper'

# Trendと会場（Venue）の紐付け（issue #1689）
class TrendVenueTest < ActiveSupport::TestCase
  setup do
    @venue = Venue.create!(
      key: 'zepp-shinjuku', name: 'Zepp Shinjuku',
      name_log: [{ 'name' => '旧ホール', 'date' => '2000' }, { 'name' => 'Zepp Shinjuku', 'date' => '2023-04' }]
    )
  end

  def build_trend(**attrs)
    Trend.new({ date: Date.new(2024, 1, 1), publish_start_at: Time.current, unit_phenomenon: :live }.merge(attrs))
  end

  test 'venue is optional' do
    assert build_trend.valid?
  end

  test 'venue_display_name uses the venue name on the trend date' do
    assert_equal '旧ホール', build_trend(venue: @venue, date: Date.new(2010, 5, 1)).venue_display_name
    assert_equal 'Zepp Shinjuku', build_trend(venue: @venue, date: Date.new(2023, 4, 1)).venue_display_name
  end

  test 'venue_display_name prefers venue_name' do
    trend = build_trend(venue: @venue, venue_name: '旧ホール（2F）', date: Date.new(2024, 1, 1))

    assert_equal '旧ホール（2F）', trend.venue_display_name
  end

  test 'venue_display_name shows venue_name even without a venue' do
    assert_equal '未登録の会場', build_trend(venue_name: '未登録の会場').venue_display_name
  end

  test 'venue_display_name is nil without venue or venue_name' do
    assert_nil build_trend.venue_display_name
  end

  test 'blank venue_name is normalized to nil' do
    trend = build_trend(venue: @venue, venue_name: '  ')
    trend.valid?

    assert_nil trend.venue_name
    assert_equal 'Zepp Shinjuku', trend.venue_display_name
  end

  test 'venue_display_name hides a discarded venue' do
    @venue.discard

    assert_nil build_trend(venue: @venue).venue_display_name
  end

  test 'venue_display_name keeps showing a venue merged into another one' do
    Venue.create!(key: 'merged-into', name: '統合先')
    @venue.update!(destination_key: 'merged-into')
    @venue.discard

    assert_equal 'Zepp Shinjuku', build_trend(venue: @venue).venue_display_name
  end

  test 'venue keeps its trends after a key change' do
    trend = build_trend(venue: @venue)
    trend.save!

    @venue.change_key!('zepp-shinjuku-tokyo')

    assert_equal @venue, trend.reload.venue
    assert_includes @venue.trends, trend
  end
end
