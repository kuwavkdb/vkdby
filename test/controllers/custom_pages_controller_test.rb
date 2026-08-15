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
end
