# frozen_string_literal: true

require 'test_helper'

class PeopleControllerTest < ActionDispatch::IntegrationTest # rubocop:disable Metrics/ClassLength
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

  # issue #1770: 検索語の _ はワイルドカードではなく文字どおりに扱う
  test 'index treats an underscore in the query literally' do
    Person.create!(name: 'Wild_Card Person', key: 'like-escape-people-index-underscore', status: :active)
    Person.create!(name: 'WildxCard Person', key: 'like-escape-people-index-other', status: :active)

    get people_path(q: 'Wild_Card')

    assert_response :success
    assert_includes response.body, 'Wild_Card Person'
    assert_not_includes response.body, 'WildxCard Person'
  end

  test 'search treats an underscore in the query literally' do
    Person.create!(name: 'Wild_Card Person', key: 'like-escape-people-search-underscore', status: :active)
    Person.create!(name: 'WildxCard Person', key: 'like-escape-people-search-other', status: :active)

    get search_people_path(q: 'Wild_Card')

    assert_response :success
    names = response.parsed_body.pluck('name')
    assert_includes names, 'Wild_Card Person'
    assert_not_includes names, 'WildxCard Person'
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

  test 'index lists hometown options in prefecture order rather than by count' do
    3.times { |i| Person.create!(name: "都道府県順テスト沖縄#{i}", key: "people-index-hometown-order-okinawa-#{i}", status: :active, hometown: '沖縄県') }
    Person.create!(name: '都道府県順テスト北海道', key: 'people-index-hometown-order-hokkaido', status: :active, hometown: '北海道')

    get people_path

    assert_response :success
    hokkaido_index = response.body.index('北海道')
    okinawa_index = response.body.index('沖縄県')
    assert hokkaido_index && okinawa_index, '北海道・沖縄県のボタンが表示されていること'
    assert_operator hokkaido_index, :<, okinawa_index
  end

  test 'index ignores an invalid part, blood or status filter value' do
    person = Person.create!(name: '不正パラメータテスト', key: 'people-index-filter-invalid-value', status: :active)

    get people_path(part: 'not-a-real-part', blood: 'not-a-real-blood-type', status: 'not-a-real-status')

    assert_response :success
    assert_includes response.body, person.name
  end

  test 'index reuses cached person data filter option counts instead of recomputing them every request' do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.clear

    get people_path
    assert_response :success
    cached = Rails.cache.read(PersonFilterCounts::CACHE_KEY)
    assert cached, 'フィルタ選択肢のカウントがキャッシュされていること'

    # キャッシュを直接書き換えて、次のリクエストで再集計されず書き換えた値がそのまま
    # 使われることを確認する（＝毎リクエストではCOUNTクエリを発行していない）
    poisoned_count = (cached[:blood]['A'] || 0) + 12_345
    poisoned = cached.merge(blood: cached[:blood].merge('A' => poisoned_count))
    Rails.cache.write(PersonFilterCounts::CACHE_KEY, poisoned, expires_in: PersonFilterCounts::CACHE_TTL)

    get people_path
    assert_response :success
    assert_includes response.body, "(#{poisoned_count})"
  ensure
    Rails.cache = original_cache
  end

  test 'creating a person invalidates the cached filter option counts' do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.clear

    get people_path
    assert_response :success
    before_count = Rails.cache.read(PersonFilterCounts::CACHE_KEY)[:blood]['AB'] || 0

    Person.create!(name: 'キャッシュ失効テスト', key: 'people-index-filter-counts-expire', status: :active, blood: 'AB')
    assert_nil Rails.cache.read(PersonFilterCounts::CACHE_KEY), 'after_commitでキャッシュが削除されていること'

    get people_path
    assert_response :success
    after_count = Rails.cache.read(PersonFilterCounts::CACHE_KEY)[:blood]['AB']
    assert_equal before_count + 1, after_count
  ensure
    Rails.cache = original_cache
  end

  # issue #1855: 一覧ページの検索は名前系の列と old_history だけを探す。セクション名で探すのは /search だけ
  test 'index does not search section names' do
    person = Person.create!(name: 'IndexSectionMatchPerson', key: 'index-section-match-person-test', status: :active)
    person.sections.create!(name: 'UniqueIndexSectionNameForPersonTest', active: true)

    get people_path(q: 'UniqueIndexSectionNameForPersonTest')

    assert_response :success
    assert_not_includes response.body, 'IndexSectionMatchPerson'
  end

  # issue #1843: 個人ページのないメンバー
  test 'index lists members without a person page when searching' do
    unit = Unit.create!(name: 'UnlinkedPeopleIndexUnit', key: 'unlinked-people-index-unit', status: :active)
    snapshot = unit.unit_snapshots.create!(active: true)
    snapshot.snapshot_people.create!(person_name: 'UniqueUnlinkedPeopleIndexMember')

    get people_path(q: 'UniqueUnlinkedPeopleIndexMember')

    assert_response :success
    assert_includes response.body, '個人ページのないメンバー'
    assert_select "a[href='#{profile_path(unit.key, anchor: "snapshot-#{snapshot.id}")}']"
    assert_not_includes response.body, '検索結果が見つかりませんでした'
  end

  test 'index does not list members without a person page while a person data filter is selected' do
    unit = Unit.create!(name: 'UnlinkedPeopleFilterUnit', key: 'unlinked-people-filter-unit', status: :active)
    snapshot = unit.unit_snapshots.create!(active: true)
    snapshot.snapshot_people.create!(person_name: 'UniqueUnlinkedPeopleFilterMember')

    get people_path(q: 'UniqueUnlinkedPeopleFilterMember', part: 'vocal')

    assert_response :success
    assert_not_includes response.body, '個人ページのないメンバー'
    assert_select "a[href='#{profile_path(unit.key, anchor: "snapshot-#{snapshot.id}")}']", count: 0
  end

  test 'search suggests members without a person page after people, with a url to the unit snapshot' do
    Person.create!(name: 'UnlinkedSuggest Person', key: 'unlinked-suggest-person', status: :active)
    unit = Unit.create!(name: 'UnlinkedSuggestUnit', key: 'unlinked-suggest-unit', status: :active)
    snapshot = unit.unit_snapshots.create!(active: true)
    snapshot.snapshot_people.create!(person_name: 'UnlinkedSuggest Member')

    get search_people_path(q: 'UnlinkedSuggest')

    assert_response :success
    assert_equal ['UnlinkedSuggest Person', 'UnlinkedSuggest Member'], response.parsed_body.pluck('name')
    member = response.parsed_body.last
    assert_equal 'UnlinkedSuggestUnit', member['unit_name']
    assert_equal profile_path(unit.key, anchor: "snapshot-#{snapshot.id}"), member['url']
  end

  test 'index lists members without a person page below people with a person page' do
    Person.create!(name: 'UniqueUnlinkedOrder Person', key: 'unlinked-order-person', status: :active)
    unit = Unit.create!(name: 'UnlinkedOrderUnit', key: 'unlinked-order-unit', status: :active)
    unit.unit_snapshots.create!(active: true).snapshot_people.create!(person_name: 'UniqueUnlinkedOrder Member')

    get people_path(q: 'UniqueUnlinkedOrder')

    assert_response :success
    body = response.body
    assert_operator body.index(profile_path('unlinked-order-person')), :<, body.index('個人ページのないメンバー')
  end
end
