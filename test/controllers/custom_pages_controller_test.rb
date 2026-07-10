# frozen_string_literal: true

require 'test_helper'

class CustomPagesControllerTest < ActionDispatch::IntegrationTest
  test 'sidebar does not render a discarded unit or person referenced by a weekly trend' do
    # key未設定の既存フィクスチャが "最近の更新" 欄に混ざると別バグ(issue #874)で
    # profile_path がルート生成エラーになるため、この検証の対象外にしておく
    Unit.kept.where(key: nil).find_each(&:discard)
    Person.kept.where(key: nil).find_each(&:discard)

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
end
