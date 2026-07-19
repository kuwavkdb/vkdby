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
end
