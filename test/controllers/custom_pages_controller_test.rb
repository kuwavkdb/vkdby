# frozen_string_literal: true

require 'test_helper'

class CustomPagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    # key未設定の既存フィクスチャが "最近の更新" 欄に混ざると別バグ(issue #874)で
    # profile_path がルート生成エラーになるため、この検証の対象外にしておく
    Unit.kept.where(key: nil).find_each(&:discard)
    Person.kept.where(key: nil).find_each(&:discard)
  end

  test 'sidebar does not render a discarded unit or person referenced by a weekly trend' do
    unit = Unit.create!(name: 'Discarded Sidebar Unit', key: 'discarded-unit-sidebar-test', status: :active)
    person = Person.create!(name: 'Discarded Sidebar Person', key: 'discarded-person-sidebar-test', status: :active)
    unit.discard
    person.discard
    Trend.create!(title: 'Sidebar trend with discarded refs', date: Date.current, publish_start_at: Time.current,
                  unit_phenomenon: :other,
                  units: [{ 'unit_id' => unit.id }], people: [{ 'person_id' => person.id }])
    page = CustomPage.create!(key: 'sidebar-test-page', title: 'Sidebar Test Page', active: true, body: 'body')

    get custom_page_path(key: page.key)

    assert_response :success
    assert_not_includes response.body, 'Discarded Sidebar Unit'
    assert_not_includes response.body, 'Discarded Sidebar Person'
    assert_no_match(%r{<span class="inline-block[^"]*">\s*</span>}, response.body)
  end

  test 'renders og:image pointing at the generated title banner (issue #1263)' do
    skip 'libvips is not installed in this environment' unless ActiveStorage::VIPS_AVAILABLE

    page = CustomPage.create!(key: 'ogp-image-test-page', title: 'OGP Image Test Page', active: true, body: 'body')

    get custom_page_path(key: page.key)

    assert_response :success
    assert_includes response.body, 'property="og:image" content="http://www.example.com/rails/active_storage/'
  end

  test 'falls back to the default og:image when the per-page image cannot be generated' do
    page = CustomPage.create!(key: 'ogp-fallback-test-page', title: 'OGP Fallback Test Page', active: true,
                              body: 'body')

    stub_class_method(OgpImageGenerator, :call, nil) { get custom_page_path(key: page.key) }

    assert_response :success
    assert_includes response.body,
                    "property=\"og:image\" content=\"http://www.example.com#{Rails.application.config.site_ogp_image_path}\""
  end

  test 'system pages keep the default og:image instead of a title banner' do
    page = CustomPage.create!(key: 'index', title: 'トップページ', active: true, body: 'body')

    get custom_page_path(key: page.key)

    assert_response :success
    assert_includes response.body,
                    "property=\"og:image\" content=\"http://www.example.com#{Rails.application.config.site_ogp_image_path}\""
  end

  test 'index page shows the today teaser link with correct href and bilingual text' do
    CustomPage.create!(key: 'index', title: 'トップページ', active: true, body: 'body')
    today = Date.current

    get root_path

    assert_response :success
    assert_includes response.body, birthday_date_path(month: today.month, day: today.day)
    assert_includes response.body, '今日はなんの日？'
    assert_includes response.body, 'What Happened Today'
  end

  test 'non-index custom page does not show the today teaser link' do
    page = CustomPage.create!(key: 'other-page-for-teaser-test', title: 'Other Page', active: true, body: 'body')

    get custom_page_path(key: page.key)

    assert_response :success
    assert_not_includes response.body, '今日はなんの日？'
    assert_not_includes response.body, 'What Happened Today'
  end

  test 'sidebar excludes a unit or person tagged as unpublished from recently updated' do
    unit = Unit.create!(name: 'Unpublished Sidebar Unit', key: 'unpublished-unit-sidebar-test', status: :active)
    person = Person.create!(name: 'Unpublished Sidebar Person', key: 'unpublished-person-sidebar-test',
                            status: :active)
    tag_index = TagIndex.create!(id: Rails.application.config.unpublished_tag_ids.first, name: '掲載停止')
    TagIndexItem.create!(tag_index: tag_index, indexable: unit)
    TagIndexItem.create!(tag_index: tag_index, indexable: person)
    page = CustomPage.create!(key: 'unpublished-sidebar-test-page', title: 'Unpublished Sidebar Test Page',
                              active: true, body: 'body')

    get custom_page_path(key: page.key)

    assert_response :success
    assert_not_includes response.body, 'Unpublished Sidebar Unit'
    assert_not_includes response.body, 'Unpublished Sidebar Person'
  end

  test 'sidebar excludes a person tagged as unpublished from birthdays' do
    person = Person.create!(name: 'Unpublished Sidebar Birthday Person', key: 'unpublished-birthday-sidebar-test',
                            status: :active, birthday: Date.current)
    tag_index = TagIndex.create!(id: Rails.application.config.unpublished_tag_ids.first, name: '掲載停止')
    TagIndexItem.create!(tag_index: tag_index, indexable: person)
    page = CustomPage.create!(key: 'unpublished-birthday-sidebar-test-page',
                              title: 'Unpublished Birthday Sidebar Test Page', active: true, body: 'body')

    get custom_page_path(key: page.key)

    assert_response :success
    assert_not_includes response.body, 'Unpublished Sidebar Birthday Person'
  end

  test 'custom page body renders an embedded unit snapshot via {{snapshot}} macro' do
    unit = Unit.create!(name: 'Snapshot Embed Unit', key: 'snapshot-embed-test-unit', status: :active)
    snapshot = unit.unit_snapshots.create!(snapshot_date: '2020-01-01', current: true, active: true)
    snapshot.snapshot_people.create!(person_name: 'Snapshot Embed Member', part: :vocal, status: :active)
    page = CustomPage.create!(key: 'snapshot-embed-test-page', title: 'Snapshot Embed Page', active: true,
                              body: "本文\n\n{{snapshot #{unit.key},#{snapshot.id}}}\n\n続き")

    get custom_page_path(key: page.key)

    assert_response :success
    assert_includes response.body, 'Snapshot Embed Member'
  end

  test 'Management Information is hidden from a logged-out visitor' do
    page = CustomPage.create!(key: 'management-info-hidden-test-page', title: 'Management Info Hidden Test',
                              active: true, body: 'body')

    get custom_page_path(key: page.key)

    assert_response :success
    assert_not_includes response.body, 'Management Information'
  end

  test 'sidebar shows an item released within 5 days of today' do
    Item.create!(title: 'Sidebar New Release Item', release_date: Date.current + 3,
                 link_url: "http://example.com/sidebar-new-release-#{SecureRandom.hex(4)}")
    page = CustomPage.create!(key: 'new-releases-sidebar-test-page', title: 'New Releases Sidebar Test',
                              active: true, body: 'body')

    get custom_page_path(key: page.key)

    assert_response :success
    assert_includes response.body, 'Sidebar New Release Item'
    assert_includes response.body, '新発売商品'
  end

  test 'sidebar excludes an item released outside the 5-day window' do
    Item.create!(title: 'Sidebar Out Of Range Item', release_date: Date.current + 6,
                 link_url: "http://example.com/sidebar-out-of-range-#{SecureRandom.hex(4)}")
    page = CustomPage.create!(key: 'new-releases-out-of-range-test-page', title: 'New Releases Out Of Range Test',
                              active: true, body: 'body')

    get custom_page_path(key: page.key)

    assert_response :success
    assert_not_includes response.body, 'Sidebar Out Of Range Item'
  end

  test 'sidebar excludes a discarded item even within the 5-day window' do
    item = Item.create!(title: 'Sidebar Discarded Release Item', release_date: Date.current,
                        link_url: "http://example.com/sidebar-discarded-release-#{SecureRandom.hex(4)}")
    item.discard
    page = CustomPage.create!(key: 'new-releases-discarded-test-page', title: 'New Releases Discarded Test',
                              active: true, body: 'body')

    get custom_page_path(key: page.key)

    assert_response :success
    assert_not_includes response.body, 'Sidebar Discarded Release Item'
  end

  test 'sidebar keeps only the earliest item per artist within the 5-day window' do
    Item.create!(title: 'Sidebar Same Artist Earlier Item', release_date: Date.current - 1,
                 artists: [{ 'name' => 'Sidebar Dedup Artist' }],
                 link_url: "http://example.com/sidebar-same-artist-earlier-#{SecureRandom.hex(4)}")
    Item.create!(title: 'Sidebar Same Artist Later Item', release_date: Date.current + 1,
                 artists: [{ 'name' => 'Sidebar Dedup Artist' }],
                 link_url: "http://example.com/sidebar-same-artist-later-#{SecureRandom.hex(4)}")
    page = CustomPage.create!(key: 'new-releases-dedup-test-page', title: 'New Releases Dedup Test',
                              active: true, body: 'body')

    get custom_page_path(key: page.key)

    assert_response :success
    assert_includes response.body, 'Sidebar Same Artist Earlier Item'
    assert_not_includes response.body, 'Sidebar Same Artist Later Item'
  end

  test 'Management Information shows ID, Key and a link to old_key on the old wiki for a super_operator' do
    post login_path, params: { email: users(:one).email, password: 'password' }
    page = CustomPage.create!(key: 'management-info-visible-test-page', title: 'Management Info Visible Test',
                              active: true, body: 'body', old_key: 'management-info-visible-old-key')

    get custom_page_path(key: page.key)

    assert_response :success
    assert_includes response.body, 'Management Information'
    assert_includes response.body, page.id.to_s
    assert_includes response.body, page.key
    assert_includes response.body,
                    "#{Rails.application.config.old_key_url_base}/#{page.old_key}.html"
  end

  test 'non-index custom page shows the Last updated footer' do
    page = CustomPage.create!(key: 'last-updated-footer-test-page', title: 'Last Updated Footer Test',
                              active: true, body: 'body')

    get custom_page_path(key: page.key)

    assert_response :success
    assert_includes response.body, 'Last updated'
  end

  test 'root page hides the Last updated and Management Information footer even for a super_operator (issue #1383)' do
    post login_path, params: { email: users(:one).email, password: 'password' }
    CustomPage.create!(key: 'index', title: 'トップページ', active: true, body: 'body')

    get root_path

    assert_response :success
    assert_not_includes response.body, 'Last updated'
    assert_not_includes response.body, 'Management Information'
  end

  test '/pages/index shows the Last updated footer like a normal custom page (issue #1383)' do
    CustomPage.create!(key: 'index', title: 'トップページ', active: true, body: 'body')

    get custom_page_path(key: 'index')

    assert_response :success
    assert_includes response.body, 'Last updated'
  end
end
