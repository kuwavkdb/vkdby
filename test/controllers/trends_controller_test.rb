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

  test 'show renders the person name before the title and the unit name below when person_name_in_title is set' do
    unit = Unit.create!(name: 'Priority Unit', key: 'trend-priority-unit', status: :active)
    person = Person.create!(name: 'Priority Person', key: 'trend-priority-person', status: :active)
    trend = Trend.create!(title: 'Priority trend', date: Date.current, publish_start_at: Time.current,
                          unit_phenomenon: :other, person_phenomenon: :join_member, person_name_in_title: true,
                          units: [{ 'unit_id' => unit.id, 'name' => 'Priority Unit' }],
                          people: [{ 'person_id' => person.id, 'name' => 'Priority Person' }])

    get trend_path(trend)

    assert_response :success
    assert_match(%r{<h1[^>]*>.*href="/trend-priority-person"[^>]*>Priority Person</a>.*Priority trend.*</h1>}m,
                 response.body)
    assert_no_match(%r{<h1[^>]*>.*Priority Unit.*</h1>}m, response.body)
    assert_includes response.body, 'Priority Unit'
  end

  test 'show renders only the person name before the title when person_name_in_title is set and no unit is linked' do
    person = Person.create!(name: 'Solo Priority Person', key: 'trend-solo-priority-person', status: :active)
    trend = Trend.create!(title: 'Solo priority trend', date: Date.current, publish_start_at: Time.current,
                          person_phenomenon: :other, person_name_in_title: true,
                          people: [{ 'person_id' => person.id, 'name' => 'Solo Priority Person' }])

    get trend_path(trend)

    assert_response :success
    assert_match(%r{<h1[^>]*>.*href="/trend-solo-priority-person"[^>]*>Solo Priority Person</a>.*Solo priority trend.*</h1>}m,
                 response.body)
    assert_equal 1, response.body.scan('Solo Priority Person').size
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

  test 'show renders the X share text with multiple unit names joined by a Japanese comma' do
    unit_a = Unit.create!(name: 'Share Unit A', key: 'trend-share-unit-a', status: :active)
    unit_b = Unit.create!(name: 'Share Unit B', key: 'trend-share-unit-b', status: :active)
    trend = Trend.create!(title: 'Multi unit share trend', date: '2026-05-01', publish_start_at: Time.current,
                          unit_phenomenon: :other,
                          units: [{ 'unit_id' => unit_a.id, 'name' => 'Share Unit A' },
                                  { 'unit_id' => unit_b.id, 'name' => 'Share Unit B' }])
    login_as_admin

    get trend_path(trend)

    assert_response :success
    assert_includes response.body, '2026/05/01 Share Unit A、Share Unit B Multi unit share trend'
  end

  test 'show renders the X share text with multiple person names joined by a Japanese comma' do
    unit = Unit.create!(name: 'Share Unit C', key: 'trend-share-unit-c', status: :active)
    person_a = Person.create!(name: 'Share Person A', key: 'trend-share-person-a', status: :active)
    person_b = Person.create!(name: 'Share Person B', key: 'trend-share-person-b', status: :active)
    trend = Trend.create!(title: 'Multi person share trend', date: '2026-05-01', publish_start_at: Time.current,
                          unit_phenomenon: :other,
                          units: [{ 'unit_id' => unit.id, 'name' => 'Share Unit C' }],
                          people: [{ 'person_id' => person_a.id, 'name' => 'Share Person A' },
                                   { 'person_id' => person_b.id, 'name' => 'Share Person B' }])
    login_as_admin

    get trend_path(trend)

    assert_response :success
    assert_includes response.body, 'Share Person A、Share Person B'
  end

  test 'show returns 404 for an inactive trend when logged out' do
    trend = Trend.create!(title: 'Inactive trend', date: Date.current, publish_start_at: Time.current,
                          etc_phenomenon: :other, active: false)

    get trend_path(trend)

    assert_response :not_found
  end

  test 'show returns 404 for a trend whose publish_start_at is in the future when logged out' do
    trend = Trend.create!(title: 'Future trend', date: Date.current, publish_start_at: 1.day.from_now,
                          etc_phenomenon: :other)

    get trend_path(trend)

    assert_response :not_found
  end

  test 'show renders an inactive trend for an admin with an unpublished badge' do
    trend = Trend.create!(title: 'Inactive trend for admin', date: Date.current, publish_start_at: Time.current,
                          etc_phenomenon: :other, active: false)
    login_as_admin

    get trend_path(trend)

    assert_response :success
    assert_includes response.body, '非公開'
  end

  test 'show returns 404 for an inactive trend when logged in as a non-admin operator' do
    trend = Trend.create!(title: 'Inactive trend for operator', date: Date.current, publish_start_at: Time.current,
                          etc_phenomenon: :other, active: false)
    User.create!(email: 'trend-operator@example.com', name: 'Operator', password: 'password', role: :operator)
    post login_path, params: { email: 'trend-operator@example.com', password: 'password' }

    get trend_path(trend)

    assert_response :not_found
  end

  test 'index shows the date of a trend with an unknown day or month only as far as it is known and links to that page' do
    Trend.create!(title: 'Known date trend', date: Date.new(2020, 12, 5), publish_start_at: Time.current,
                  etc_phenomenon: :other)
    Trend.create!(title: 'Day unknown trend', date: Date.new(2020, 12, 1), publish_start_at: Time.current,
                  etc_phenomenon: :other, day_unknown: true)
    Trend.create!(title: 'Month unknown trend', date: Date.new(2020, 1, 1), publish_start_at: Time.current,
                  etc_phenomenon: :other, day_unknown: true, month_unknown: true)

    get trends_path(year: 2020)

    assert_response :success
    assert_select "a[href='#{daily_path(year: 2020, month: 12, day: 5)}']", text: '2020/12/05'
    assert_select "a[href='#{monthly_path(year: 2020, month: 12)}']", text: '2020/12'
    assert_select "a[href='#{yearly_path(year: 2020)}']", text: '2020'
    assert_select "a[href='#{daily_path(year: 2020, month: 12, day: 1)}']", count: 0
    assert_select "a[href='#{daily_path(year: 2020, month: 1, day: 1)}']", count: 0
  end

  test 'show lists the unit trends with dates only as far as they are known (issue #1917)' do
    unit = Unit.create!(name: 'Date Label Unit', key: 'trend-date-label-unit', status: :active)
    trend = Trend.create!(title: 'Current trend', date: Date.new(2020, 12, 5), publish_start_at: Time.current,
                          unit_phenomenon: :other, units: [{ 'unit_id' => unit.id, 'name' => unit.name }])
    Trend.create!(title: 'Day unknown unit trend', date: Date.new(2020, 11, 1), publish_start_at: Time.current,
                  unit_phenomenon: :other, day_unknown: true, units: [{ 'unit_id' => unit.id, 'name' => unit.name }])

    get trend_path(trend)

    assert_response :success
    assert_includes response.body, 'Day unknown unit trend'
    assert_includes response.body, '2020/11'
    assert_not_includes response.body, '2020/11/01'
  end

  test 'index does not list an inactive trend when logged out' do
    Trend.create!(title: 'Inactive listing trend', date: Date.current, publish_start_at: Time.current,
                  etc_phenomenon: :other, active: false)

    get trends_path

    assert_response :success
    assert_not_includes response.body, 'Inactive listing trend'
  end

  test 'index lists an inactive trend for an admin with an unpublished badge' do
    Trend.create!(title: 'Inactive listing trend for admin', date: Date.current, publish_start_at: Time.current,
                  etc_phenomenon: :other, active: false)
    login_as_admin

    get trends_path

    assert_response :success
    assert_includes response.body, 'Inactive listing trend for admin'
    assert_includes response.body, '非公開'
  end

  test 'show renders the X share text with the person name first when person_name_in_title is set' do
    unit = Unit.create!(name: 'Share Priority Unit', key: 'trend-share-priority-unit', status: :active)
    person = Person.create!(name: 'Share Priority Person', key: 'trend-share-priority-person', status: :active)
    trend = Trend.create!(title: 'Share priority trend', date: '2026-05-01', publish_start_at: Time.current,
                          unit_phenomenon: :other, person_name_in_title: true,
                          units: [{ 'unit_id' => unit.id, 'name' => 'Share Priority Unit' }],
                          people: [{ 'person_id' => person.id, 'name' => 'Share Priority Person' }])
    login_as_admin

    get trend_path(trend)

    assert_response :success
    assert_includes response.body, '2026/05/01 Share Priority Person Share priority trend'
    assert_includes response.body, 'Share Priority Unit'
  end

  private

  def login_as_admin
    admin = User.create!(email: 'trend-share-admin@example.com', name: 'Admin', password: 'password', role: :admin)
    post login_path, params: { email: admin.email, password: 'password' }
  end

  test 'show renders the news release label for a news release trend (issue #2014)' do
    trend = Trend.create!(title: 'News release trend', date: Date.current,
                          publish_start_at: Time.zone.local(2020, 1, 2, 3, 4, 5),
                          etc_phenomenon: :other, news_release: true, news_release_source: 'Example Records')

    get trend_path(trend)

    assert_response :success
    assert_select 'span', text: 'ニュースリリース'
    assert_select 'span', text: 'Example Records'
    assert_select 'time', text: '2020年1月2日 3時04分'
  end

  test 'show does not render the news release label for an ordinary trend' do
    trend = Trend.create!(title: 'Ordinary trend', date: Date.current, publish_start_at: 1.minute.ago,
                          etc_phenomenon: :other)

    get trend_path(trend)

    assert_response :success
    assert_select 'span', text: 'ニュースリリース', count: 0
  end

  test 'index renders the news release label next to a news release trend (issue #2014)' do
    Trend.create!(title: 'News release listing trend', date: Date.current, publish_start_at: 1.minute.ago,
                  etc_phenomenon: :other, news_release: true, news_release_source: 'Example Records')

    get trends_path

    assert_response :success
    assert_select 'span', text: 'ニュースリリース', count: 1
  end

  test 'index does not list a scheduled news release before its publish_start_at when logged out (issue #2014)' do
    Trend.create!(title: 'Embargoed news release', date: Date.current, publish_start_at: 1.day.from_now,
                  etc_phenomenon: :other, news_release: true, news_release_source: 'Example Records')

    get trends_path

    assert_response :success
    assert_not_includes response.body, 'Embargoed news release'
  end

  test 'show renders the publish_start_at of a scheduled trend for an admin (issue #2014)' do
    trend = Trend.create!(title: 'Scheduled trend for admin', date: Date.current,
                          publish_start_at: Time.zone.local(2099, 1, 2, 3, 4, 5), etc_phenomenon: :other)
    login_as_admin

    get trend_path(trend)

    assert_response :success
    assert_includes response.body, '2099/01/02 03:04:05 公開'
    assert_not_includes response.body, '非公開（管理者のみ閲覧可）'
  end

  test 'index renders the publish_start_at of a scheduled trend for an admin (issue #2014)' do
    Trend.create!(title: 'Scheduled listing trend for admin', date: Date.current,
                  publish_start_at: Time.zone.local(2099, 1, 2, 3, 4, 5), etc_phenomenon: :other)
    login_as_admin

    get trends_path

    assert_response :success
    assert_includes response.body, '2099/01/02 03:04:05 公開'
  end

  test 'show marks an unpublished unit trend in the related list for an admin (issue #2014)' do
    unit = Unit.create!(name: 'Related Unpublished Unit', key: 'trend-related-unpublished-unit', status: :active)
    trend = Trend.create!(title: 'Current published trend', date: Date.new(2020, 12, 5), publish_start_at: 1.minute.ago,
                          unit_phenomenon: :other, units: [{ 'unit_id' => unit.id, 'name' => unit.name }])
    Trend.create!(title: 'Related scheduled trend', date: Date.new(2020, 12, 6), publish_start_at: 1.day.from_now,
                  unit_phenomenon: :other, units: [{ 'unit_id' => unit.id, 'name' => unit.name }])
    login_as_admin

    get trend_path(trend)

    assert_response :success
    assert_includes response.body, 'Related scheduled trend'
    assert_select '.sr-only', text: '（未公開）', count: 1
  end

  test 'show renders the scheduled badge beside the publish time of a scheduled news release for an admin (issue #2014)' do
    trend = Trend.create!(title: 'Scheduled news release', date: Date.current,
                          publish_start_at: Time.zone.local(2099, 1, 2, 3, 4, 5), etc_phenomenon: :other,
                          news_release: true, news_release_source: 'Example Records')
    login_as_admin

    get trend_path(trend)

    assert_response :success
    assert_select 'time', text: '2099年1月2日 3時04分'
    assert_select 'time + span', text: '公開予定', count: 1
    assert_not_includes response.body, '2099/01/02 03:04:05 公開'
  end

  test 'show renders the attached image with the title as alt text when image_alt is blank (issue #2014)' do
    trend = Trend.create!(title: 'Image trend', date: Date.current, publish_start_at: 1.minute.ago, etc_phenomenon: :other)
    trend.image.attach(io: file_fixture('submission_image.png').open, filename: 'a.png', content_type: 'image/png')

    get trend_path(trend)

    assert_response :success
    assert_select "figure img[alt='Image trend']"
  end

  test 'show uses the attached image as og:image only for a news release (issue #2014)' do
    news = Trend.create!(title: 'News image', date: Date.current, publish_start_at: 1.minute.ago, etc_phenomenon: :other,
                         news_release: true, news_release_source: 'Example Records')
    news.image.attach(io: file_fixture('submission_image.png').open, filename: 'news.png', content_type: 'image/png')
    plain = Trend.create!(title: 'Plain image', date: Date.current, publish_start_at: 1.minute.ago, etc_phenomenon: :other)
    plain.image.attach(io: file_fixture('submission_image.png').open, filename: 'plain.png', content_type: 'image/png')

    get trend_path(news)
    assert_select "meta[property='og:image'][content*='news.png']"

    get trend_path(plain)
    assert_select "meta[property='og:image'][content*='plain.png']", count: 0
  end

  test 'show renders the body of a news release as plain text keeping blank lines (issue #2014)' do
    trend = Trend.create!(title: 'Plain body', date: Date.current, publish_start_at: 1.minute.ago, etc_phenomenon: :other,
                          news_release: true, news_release_source: 'Example Records',
                          content: "1行目\n\n\n\n* 箇条書きではない\n<b>太字ではない</b>")

    get trend_path(trend)

    assert_response :success
    assert_select 'div.whitespace-pre-line' do |elements|
      assert_includes elements.first.text, "1行目\n\n\n\n* 箇条書きではない"
    end
    assert_includes response.body, '&lt;b&gt;太字ではない&lt;/b&gt;'
    assert_select 'div.whitespace-pre-line li', count: 0
  end

  test 'show renders [ニュースリリース] at the head of the X share text of a news release (issue #2014)' do
    trend = Trend.create!(title: 'ニュースの件名', date: Date.new(2026, 11, 6), publish_start_at: 1.minute.ago,
                          etc_phenomenon: :other, news_release: true, news_release_source: 'Example Records')
    login_as_admin

    get trend_path(trend)

    assert_response :success
    assert_select "textarea[aria-label='Xシェア用テキスト']" do |elements|
      assert elements.first.text.strip.start_with?('[ニュースリリース] 2026/11/06 ニュースの件名')
    end
  end

  test 'show does not render [ニュースリリース] in the X share text of an ordinary trend' do
    trend = Trend.create!(title: '普通の件名', date: Date.new(2026, 11, 6), publish_start_at: 1.minute.ago, etc_phenomenon: :other)
    login_as_admin

    get trend_path(trend)

    assert_select "textarea[aria-label='Xシェア用テキスト']" do |elements|
      assert_not_includes elements.first.text, '[ニュースリリース]'
    end
  end

  test 'show lists items released on the trend date by the same artist below the trend (issue #2014)' do
    unit = Unit.create!(name: 'Same Day Unit', key: 'trend-same-day-unit', status: :active)
    person = Person.create!(name: 'Same Day Person', key: 'trend-same-day-person')
    trend = Trend.create!(title: 'Release trend', date: Date.new(2026, 11, 6), publish_start_at: 1.minute.ago,
                          unit_phenomenon: :other, units: [{ 'unit_id' => unit.id, 'name' => unit.name }],
                          people: [{ 'person_id' => person.id, 'name' => person.name }])
    Item.create!(title: 'Unit Same Day Single', release_date: Date.new(2026, 11, 6), link_url: 'https://example.com/same-day-unit',
                 artists: [{ 'name' => unit.name, 'key' => unit.key }])
    Item.create!(title: 'Person Same Day Single', release_date: Date.new(2026, 11, 6), link_url: 'https://example.com/same-day-person',
                 artists: [{ 'name' => person.name, 'key' => person.key }])
    Item.create!(title: 'Unit Other Day Single', release_date: Date.new(2026, 11, 7), link_url: 'https://example.com/other-day',
                 artists: [{ 'name' => unit.name, 'key' => unit.key }])
    Item.create!(title: 'Other Artist Same Day Single', release_date: Date.new(2026, 11, 6), link_url: 'https://example.com/other-artist',
                 artists: [{ 'name' => 'Other Artist', 'key' => 'other-artist' }])

    get trend_path(trend)

    assert_response :success
    assert_select 'section[aria-labelledby=same-day-items-heading]' do
      assert_select '*', text: /Unit Same Day Single/
      assert_select '*', text: /Person Same Day Single/
      assert_select '*', text: /Unit Other Day Single/, count: 0
      assert_select '*', text: /Other Artist Same Day Single/, count: 0
    end
    # 同じ日に発売のアイテムは、下の Recent Items に重ねて出さない
    assert_select 'h3', text: 'Unit Same Day Single', count: 1
  end

  test 'show does not list same day items for a trend whose day is unknown (issue #2014)' do
    unit = Unit.create!(name: 'Day Unknown Unit', key: 'trend-day-unknown-unit', status: :active)
    trend = Trend.create!(title: 'Day unknown trend', date: Date.new(2026, 11, 1), day_unknown: true, publish_start_at: 1.minute.ago,
                          unit_phenomenon: :other, units: [{ 'unit_id' => unit.id, 'name' => unit.name }])
    Item.create!(title: 'First Day Single', release_date: Date.new(2026, 11, 1), link_url: 'https://example.com/first-day',
                 artists: [{ 'name' => unit.name, 'key' => unit.key }])

    get trend_path(trend)

    assert_response :success
    assert_select 'section[aria-labelledby=same-day-items-heading]', count: 0
  end

  test 'show renders the bottom image above the same day items (issue #2014)' do
    unit = Unit.create!(name: 'Bottom Image Unit', key: 'trend-bottom-image-unit', status: :active)
    trend = Trend.create!(title: 'Bottom image trend', date: Date.new(2026, 11, 6), publish_start_at: 1.minute.ago,
                          unit_phenomenon: :other, units: [{ 'unit_id' => unit.id, 'name' => unit.name }],
                          bottom_image_alt: '告知画像')
    trend.bottom_image.attach(io: file_fixture('submission_image.png').open, filename: 'bottom.png', content_type: 'image/png')
    Item.create!(title: 'Bottom Image Single', release_date: Date.new(2026, 11, 6), link_url: 'https://example.com/bottom-image',
                 artists: [{ 'name' => unit.name, 'key' => unit.key }])

    get trend_path(trend)

    assert_response :success
    assert_select "figure img[alt='告知画像']", count: 1
    body = response.body
    assert_operator body.index('告知画像'), :<, body.index('same-day-items-heading')
  end
end

