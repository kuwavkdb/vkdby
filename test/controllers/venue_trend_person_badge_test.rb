# frozen_string_literal: true

require 'test_helper'

# 会場ページの動向一覧で、個人名を件名の前に出す動向の個人名（issue #1796）
class VenueTrendPersonBadgeTest < ActionDispatch::IntegrationTest
  setup do
    @venue = Venue.create!(key: 'shinjuku-loft', name: '新宿LOFT')
    @person = Person.create!(key: 'some-person', name: '個人A', status: :active)
    @unit = Unit.create!(key: 'some-unit', name: 'ユニットA', status: :active)
  end

  test 'shows person names for a person trend that is not linked to a unit' do
    create_trend(person_phenomenon: :join_member,
                 people: [{ 'person_id' => @person.id, 'name' => '個人A' }, { 'person_id' => nil, 'name' => '未登録の個人' }])

    get venue_path(@venue.key)

    assert_response :success
    assert_select "a[href='#{profile_path(@person.key)}']", text: '個人A'
    assert_select 'span', text: '未登録の個人'
  end

  test 'shows person names before unit names when person_name_in_title is set' do
    create_trend(unit_phenomenon: :live, person_name_in_title: true,
                 units: [{ 'unit_id' => @unit.id, 'name' => 'ユニットA' }],
                 people: [{ 'person_id' => @person.id, 'name' => '個人A' }])

    get venue_path(@venue.key)

    assert_response :success
    hrefs = css_select('#venue-trends-heading ~ ul a').map { |a| a['href'] }
    assert_equal [profile_path(@person.key), profile_path(@unit.key)], hrefs.first(2)
  end

  test 'does not show person names for a unit trend without the person priority' do
    create_trend(unit_phenomenon: :live,
                 units: [{ 'unit_id' => @unit.id, 'name' => 'ユニットA' }],
                 people: [{ 'person_id' => @person.id, 'name' => '個人A' }])

    get venue_path(@venue.key)

    assert_response :success
    assert_select "a[href='#{profile_path(@unit.key)}']", text: 'ユニットA'
    assert_select "a[href='#{profile_path(@person.key)}']", count: 0
  end

  private

  def create_trend(**attrs)
    Trend.create!(title: 'ライブ', date: Date.new(2020, 1, 1), publish_start_at: 1.day.ago, venue: @venue, **attrs)
  end
end
