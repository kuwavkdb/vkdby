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

  test 'show renders a person name badge before the title when person_phenomenon is set and no unit is linked' do
    person = Person.create!(name: 'Solo Badge Person', key: 'trend-solo-badge-person', status: :active)
    trend = Trend.create!(title: '死去', date: Date.current, publish_start_at: Time.current,
                          person_phenomenon: :other,
                          people: [{ 'person_id' => person.id, 'name' => 'Solo Badge Person' }])

    get trend_path(trend)

    assert_response :success
    assert_match(%r{<h1[^>]*>.*href="/trend-solo-badge-person"[^>]*>Solo Badge Person</a>.*死去.*</h1>}m, response.body)
  end

  test 'show does not duplicate the person badge below the title when it is already shown before the title' do
    person = Person.create!(name: 'No Duplicate Person', key: 'trend-no-duplicate-person', status: :active)
    trend = Trend.create!(title: '死去', date: Date.current, publish_start_at: Time.current,
                          person_phenomenon: :other,
                          people: [{ 'person_id' => person.id, 'name' => 'No Duplicate Person' }])

    get trend_path(trend)

    assert_response :success
    assert_equal 1, response.body.scan('No Duplicate Person').size
  end

  test 'show does not render a person badge before the title when the trend is linked to a unit' do
    unit = Unit.create!(name: 'Badge Unit', key: 'trend-badge-unit', status: :active)
    person = Person.create!(name: 'Member Badge Person', key: 'trend-member-badge-person', status: :active)
    trend = Trend.create!(title: 'Member trend', date: Date.current, publish_start_at: Time.current,
                          unit_phenomenon: :other, person_phenomenon: :join_member,
                          units: [{ 'unit_id' => unit.id, 'name' => 'Badge Unit' }],
                          people: [{ 'person_id' => person.id, 'name' => 'Member Badge Person' }])

    get trend_path(trend)

    assert_response :success
    assert_no_match(%r{<h1[^>]*>.*Member Badge Person.*</h1>}m, response.body)
    assert_includes response.body, 'Member Badge Person'
  end

  test 'show does not render the X share text for a logged out visitor' do
    trend = Trend.create!(title: 'Share text trend', date: Date.current, publish_start_at: Time.current,
                          etc_phenomenon: :other)

    get trend_path(trend)

    assert_response :success
    assert_not_includes response.body, 'trend-x-share-text'
  end

  test 'show page title, og:title and twitter:title include the unit name and date but not the person name' do
    unit = Unit.create!(name: 'Title Unit', key: 'trend-title-unit', status: :active)
    person = Person.create!(name: 'Title Person', key: 'trend-title-person', status: :active)
    trend = Trend.create!(title: 'Title Trend', date: '2026-05-01', publish_start_at: Time.current,
                          unit_phenomenon: :other, person_phenomenon: :other,
                          units: [{ 'unit_id' => unit.id, 'name' => 'Title Unit' }],
                          people: [{ 'person_id' => person.id, 'name' => 'Title Person' }])

    get trend_path(trend)

    assert_response :success
    assert_includes response.body, '<title>Title Unit Title Trend 2026/05/01 - '
    assert_includes response.body, 'property="og:title" content="Title Unit Title Trend 2026/05/01"'
    assert_includes response.body, 'name="twitter:title" content="Title Unit Title Trend 2026/05/01"'
    assert_not_includes response.body, '<title>Title Unit Title Person'
  end

  test 'show page title omits the person name for a person-only trend' do
    person = Person.create!(name: 'Solo Title Person', key: 'trend-title-solo-person', status: :active)
    trend = Trend.create!(title: 'Solo Title Trend', date: '2026-05-01', publish_start_at: Time.current,
                          person_phenomenon: :other,
                          people: [{ 'person_id' => person.id, 'name' => 'Solo Title Person' }])

    get trend_path(trend)

    assert_response :success
    assert_includes response.body, '<title>Solo Title Trend 2026/05/01 - '
  end

  test 'show page title strips a trailing half-width parenthetical (e.g. venue name) from the trend title' do
    unit = Unit.create!(name: 'Venue Unit', key: 'trend-title-venue-unit', status: :active)
    trend = Trend.create!(title: '無期限活動休止(Shibuya Spotify O-EAST)', date: '2026-05-01',
                          publish_start_at: Time.current, unit_phenomenon: :other,
                          units: [{ 'unit_id' => unit.id, 'name' => 'Venue Unit' }])

    get trend_path(trend)

    assert_response :success
    assert_includes response.body, '<title>Venue Unit 無期限活動休止 2026/05/01 - '
    assert_includes response.body, 'content="Venue Unit 無期限活動休止 2026/05/01"'
  end

  test 'show renders og:image pointing at the generated per-trend banner' do
    skip 'libvips is not installed in this environment' unless ActiveStorage::VIPS_AVAILABLE

    unit = Unit.create!(name: 'OGP Image Unit', key: 'trend-ogp-image-unit', status: :active)
    trend = Trend.create!(title: 'OGP Image Trend', date: Date.current, publish_start_at: Time.current,
                          unit_phenomenon: :other, units: [{ 'unit_id' => unit.id, 'name' => 'OGP Image Unit' }])

    get trend_path(trend)

    assert_response :success
    assert_includes response.body, 'property="og:image" content="http://www.example.com/rails/active_storage/'
  end

  test 'show falls back to the default og:image when the per-trend banner cannot be generated' do
    trend = Trend.create!(title: 'Fallback Image Trend', date: Date.current, publish_start_at: Time.current,
                          etc_phenomenon: :other)

    stub_class_method(OgpImageGenerator, :call, nil) { get trend_path(trend) }

    assert_response :success
    assert_includes response.body,
                    "property=\"og:image\" content=\"http://www.example.com#{Rails.application.config.site_ogp_image_path}\""
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
