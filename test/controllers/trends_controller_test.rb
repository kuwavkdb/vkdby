# frozen_string_literal: true

require 'test_helper'

class TrendsControllerTest < ActionDispatch::IntegrationTest
  test 'index does not render a discarded unit referenced by a trend' do
    unit = Unit.create!(name: 'Discarded Trend Unit', key: 'discarded-unit-trends-test', status: :active)
    unit.discard
    Trend.create!(title: 'Trend with discarded unit', date: Date.current, publish_start_at: Time.current,
                  unit_phenomenon: :other, units: [{ 'unit_id' => unit.id }])

    get trends_path

    assert_response :success
    assert_not_includes response.body, 'Discarded Trend Unit'
  end

  test 'show does not render a discarded unit or person referenced by a trend' do
    unit = Unit.create!(name: 'Discarded Show Unit', key: 'discarded-unit-trends-show-test', status: :active)
    person = Person.create!(name: 'Discarded Show Person', key: 'discarded-person-trends-show-test', status: :active)
    unit.discard
    person.discard
    trend = Trend.create!(title: 'Trend with discarded refs', date: Date.current, publish_start_at: Time.current,
                          unit_phenomenon: :other,
                          units: [{ 'unit_id' => unit.id }], people: [{ 'person_id' => person.id }])

    get trend_path(trend)

    assert_response :success
    assert_not_includes response.body, 'Discarded Show Unit'
    assert_not_includes response.body, 'Discarded Show Person'
  end

  test 'show sidebar shows the recorded name for a related trend when it differs from the current unit name' do
    unit = Unit.create!(name: 'Sidebar Unit', key: 'trend-sidebar-unit', status: :active)
    main_trend = Trend.create!(title: 'Main trend', date: Date.current, publish_start_at: Time.current,
                               unit_phenomenon: :other, units: [{ 'unit_id' => unit.id, 'name' => 'Sidebar Unit' }])
    Trend.create!(title: 'Older trend', date: Date.current - 1, publish_start_at: Time.current,
                  unit_phenomenon: :other, units: [{ 'unit_id' => unit.id, 'name' => 'Old Sidebar Name' }])

    get trend_path(main_trend)

    assert_response :success
    assert_includes response.body, 'Old Sidebar Name'
  end
end
