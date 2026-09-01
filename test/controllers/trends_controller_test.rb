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

  test 'show does not render the X share text for a logged out visitor' do
    trend = Trend.create!(title: 'Share text trend', date: Date.current, publish_start_at: Time.current,
                          etc_phenomenon: :other)

    get trend_path(trend)

    assert_response :success
    assert_not_includes response.body, 'trend-x-share-text'
  end

  test 'show renders the X share text for a logged in admin, including units, people, URL and hashtag' do
    unit = Unit.create!(name: 'Share Unit', key: 'trend-share-unit', status: :active)
    person = Person.create!(name: 'Share Person', key: 'trend-share-person', status: :active)
    trend = Trend.create!(title: 'Share text trend', date: '2026-05-01', publish_start_at: Time.current,
                          unit_phenomenon: :other,
                          units: [{ 'unit_id' => unit.id, 'name' => 'Share Unit' }],
                          people: [{ 'person_id' => person.id, 'name' => 'Share Person' }])
    login_as_admin

    get trend_path(trend)

    assert_response :success
    assert_includes response.body, 'trend-x-share-text'
    assert_includes response.body, '2026/05/01 Share Unit Share text trend'
    assert_includes response.body, 'Share Person'
    assert_includes response.body, CGI.escapeHTML(trend_url(trend))
    assert_includes response.body, '#vkdb'
  end

  private

  def login_as_admin
    admin = User.create!(email: 'trend-share-admin@example.com', name: 'Admin', password: 'password', role: :admin)
    post login_path, params: { email: admin.email, password: 'password' }
  end
end
