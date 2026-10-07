# frozen_string_literal: true

require 'test_helper'

# 会場ページの動向一覧のユニットラベル（issue #1782）とサイドバー
class VenueTrendUnitLinksTest < ActionDispatch::IntegrationTest
  test 'show links unit labels of trends to unit pages only for publicly visible units' do
    venue = Venue.create!(key: 'shinjuku-loft', name: '新宿LOFT')
    unit = Unit.create!(key: 'visible-unit', name: '公開ユニット', status: :active)
    Trend.create!(title: 'ワンマン', date: Date.new(2020, 1, 1), publish_start_at: 1.day.ago, unit_phenomenon: :live,
                  venue: venue, units: [{ 'unit_id' => unit.id, 'name' => '公開ユニット' },
                                        { 'unit_id' => nil, 'name' => '未登録ユニット' }])

    get venue_path(venue.key)

    assert_response :success
    assert_select "a[href='#{profile_path(unit.key)}']", text: '公開ユニット'
    assert_select 'span', text: '未登録ユニット'
    assert_select 'a', text: '未登録ユニット', count: 0
  end

  test 'show renders the shared sidebar like unit and person pages' do
    venue = Venue.create!(key: 'shinjuku-loft', name: '新宿LOFT')

    get venue_path(venue.key)

    assert_response :success
    assert_select 'h2', text: '最近の更新', minimum: 1
  end
end
