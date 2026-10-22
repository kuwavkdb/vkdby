# frozen_string_literal: true

require 'test_helper'

class MonthlyControllerTest < ActionDispatch::IntegrationTest
  test '月別ページの日付不明欄に非公開・公開予定の動向を表示しない（issue #1891）' do
    Trend.create!(title: '公開中の日付不明動向', date: Date.new(1995, 5, 1), day_unknown: true,
                  publish_start_at: 1.day.ago, unit_phenomenon: :other)
    Trend.create!(title: '非公開の日付不明動向', date: Date.new(1995, 5, 1), day_unknown: true,
                  publish_start_at: 1.day.ago, unit_phenomenon: :other, active: false)
    Trend.create!(title: '公開予定の日付不明動向', date: Date.new(1995, 5, 1), day_unknown: true,
                  publish_start_at: 1.day.from_now, unit_phenomenon: :other)

    get monthly_path(year: 1995, month: 5)

    assert_response :success
    assert_includes response.body, '公開中の日付不明動向'
    assert_not_includes response.body, '非公開の日付不明動向'
    assert_not_includes response.body, '公開予定の日付不明動向'
  end
end
