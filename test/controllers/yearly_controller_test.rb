# frozen_string_literal: true

require 'test_helper'

class YearlyControllerTest < ActionDispatch::IntegrationTest
  test 'yearly page excludes a person tagged as unpublished from the born persons list' do
    person = Person.create!(name: 'Unpublished Yearly Person', key: 'person-unpublished-yearly',
                            status: :active, birth_year: 1999, birthday: Date.new(1904, 5, 1))
    tag_index = TagIndex.create!(id: Rails.application.config.unpublished_tag_ids.first, name: '掲載停止')
    TagIndexItem.create!(tag_index: tag_index, indexable: person)

    get yearly_path(year: 1999)

    assert_response :success
    assert_not_includes response.body, 'Unpublished Yearly Person'
  end

  test '年別ページの月日不明欄に非公開・公開予定の動向を表示しない（issue #1891）' do
    Trend.create!(title: '公開中の月日不明動向', date: Date.new(1995, 1, 1), month_unknown: true, day_unknown: true,
                  publish_start_at: 1.day.ago, unit_phenomenon: :other)
    Trend.create!(title: '非公開の月日不明動向', date: Date.new(1995, 1, 1), month_unknown: true, day_unknown: true,
                  publish_start_at: 1.day.ago, unit_phenomenon: :other, active: false)
    Trend.create!(title: '公開予定の月日不明動向', date: Date.new(1995, 1, 1), month_unknown: true, day_unknown: true,
                  publish_start_at: 1.day.from_now, unit_phenomenon: :other)

    get yearly_path(year: 1995)

    assert_response :success
    assert_includes response.body, '公開中の月日不明動向'
    assert_not_includes response.body, '非公開の月日不明動向'
    assert_not_includes response.body, '公開予定の月日不明動向'
  end
end
