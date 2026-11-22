# frozen_string_literal: true

require 'test_helper'

# issue #2092: 「個人名を件名前に優先表示する」動向は、一覧系の画面でもユニット名の代わりに個人名を出す
class TrendPersonLeadBadgeTest < ActionDispatch::IntegrationTest
  setup do
    @date = Date.new(2026, 5, 10)
    @unit = Unit.create!(key: 'lead-badge-unit', name: 'リードユニット', status: :active)
    @person = Person.create!(key: 'lead-badge-person', name: 'リード個人', status: :active)
    Trend.create!(title: '個人を優先する動向', date: @date, publish_start_at: 1.day.ago, unit_phenomenon: :live,
                  person_name_in_title: true,
                  units: [{ 'unit_id' => @unit.id, 'name' => 'リードユニット' }],
                  people: [{ 'person_id' => @person.id, 'name' => 'リード個人' }])
  end

  def assert_person_instead_of_unit
    assert_response :success
    assert_select "a[href='#{profile_path(@person.key)}']", text: 'リード個人'
    assert_select "a[href='#{profile_path(@unit.key)}']", count: 0
  end

  test '動向の一覧' do
    get trends_path(year: @date.year)

    assert_person_instead_of_unit
  end

  test '日付別のページ' do
    get daily_path(year: @date.year, month: @date.month, day: @date.day)

    assert_person_instead_of_unit
  end

  test '個人のページの動向一覧に本人の名前を出す' do
    get profile_path(@person.key)

    assert_response :success
    assert_select '#trends', text: /リード個人/
  end

  test 'ユニットのページの動向一覧に個人名を出す' do
    get profile_path(@unit.key)

    assert_response :success
    assert_select '#trends', text: /リード個人/
  end
end
