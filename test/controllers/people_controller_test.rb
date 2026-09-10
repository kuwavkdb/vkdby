# frozen_string_literal: true

require 'test_helper'

class PeopleControllerTest < ActionDispatch::IntegrationTest
  test 'index finds a person whose name is half-width when queried with full-width alphanumerics' do
    Person.create!(name: 'ABC123', key: 'zenkaku-search-people-index-test', status: :active)

    get people_path(q: 'ＡＢＣ１２３')

    assert_response :success
    assert_includes response.body, 'ABC123'
  end

  test 'search finds a person whose name is half-width when queried with full-width alphanumerics' do
    Person.create!(name: 'ABC123', key: 'zenkaku-search-people-autocomplete-test', status: :active)

    get search_people_path(q: 'ＡＢＣ１２３')

    assert_response :success
    assert_includes response.parsed_body.pluck('name'), 'ABC123'
  end

  test 'index filters by part using person data' do
    vocal = Person.create!(name: 'パートテスト・ボーカル', key: 'people-index-filter-part-vocal', status: :active, parts: ['vocal'])
    Person.create!(name: 'パートテスト・ギター', key: 'people-index-filter-part-guitar', status: :active, parts: ['guitar'])

    get people_path(part: 'vocal')

    assert_response :success
    assert_includes response.body, vocal.name
    assert_not_includes response.body, 'パートテスト・ギター'
  end

  test 'index filters by blood type using person data' do
    person_a = Person.create!(name: '血液型テストA', key: 'people-index-filter-blood-a', status: :active, blood: 'A')
    Person.create!(name: '血液型テストB', key: 'people-index-filter-blood-b', status: :active, blood: 'B')

    get people_path(blood: 'A')

    assert_response :success
    assert_includes response.body, person_a.name
    assert_not_includes response.body, '血液型テストB'
  end

  test 'index filters by hometown using person data' do
    tokyo = Person.create!(name: '出身地テスト東京', key: 'people-index-filter-hometown-tokyo', status: :active, hometown: '東京都')
    Person.create!(name: '出身地テスト大阪', key: 'people-index-filter-hometown-osaka', status: :active, hometown: '大阪府')

    get people_path(hometown: '東京都')

    assert_response :success
    assert_includes response.body, tokyo.name
    assert_not_includes response.body, '出身地テスト大阪'
  end

  test 'index filters by status using person data' do
    retired = Person.create!(name: 'ステータステスト引退', key: 'people-index-filter-status-retirement', status: :retirement)
    Person.create!(name: 'ステータステスト活動中', key: 'people-index-filter-status-active', status: :active)

    get people_path(status: 'retirement')

    assert_response :success
    assert_includes response.body, retired.name
    assert_not_includes response.body, 'ステータステスト活動中'
  end

  test 'index ignores an invalid part, blood or status filter value' do
    person = Person.create!(name: '不正パラメータテスト', key: 'people-index-filter-invalid-value', status: :active)

    get people_path(part: 'not-a-real-part', blood: 'not-a-real-blood-type', status: 'not-a-real-status')

    assert_response :success
    assert_includes response.body, person.name
  end
end
