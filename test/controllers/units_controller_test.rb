# frozen_string_literal: true

require 'test_helper'

class UnitsControllerTest < ActionDispatch::IntegrationTest
  test 'index finds a unit whose name is half-width when queried with full-width alphanumerics' do
    Unit.create!(name: 'ABC123', key: 'zenkaku-search-units-index-test', status: :active)

    get units_path(q: 'ＡＢＣ１２３')

    assert_response :success
    assert_includes response.body, 'ABC123'
  end

  test 'search finds a unit whose name is half-width when queried with full-width alphanumerics' do
    Unit.create!(name: 'ABC123', key: 'zenkaku-search-units-autocomplete-test', status: :active)

    get search_units_path(q: 'ＡＢＣ１２３')

    assert_response :success
    assert_includes response.parsed_body.pluck('name'), 'ABC123'
  end

  # issue #1770: 検索語の _ はワイルドカードではなく文字どおりに扱う
  test 'index treats an underscore in the query literally' do
    Unit.create!(name: 'Wild_Card Unit', key: 'like-escape-units-index-underscore', status: :active)
    Unit.create!(name: 'WildxCard Unit', key: 'like-escape-units-index-other', status: :active)

    get units_path(q: 'Wild_Card')

    assert_response :success
    assert_includes response.body, 'Wild_Card Unit'
    assert_not_includes response.body, 'WildxCard Unit'
  end

  test 'search treats an underscore in the query literally' do
    Unit.create!(name: 'Wild_Card Unit', key: 'like-escape-units-search-underscore', status: :active)
    Unit.create!(name: 'WildxCard Unit', key: 'like-escape-units-search-other', status: :active)

    get search_units_path(q: 'Wild_Card')

    assert_response :success
    names = response.parsed_body.pluck('name')
    assert_includes names, 'Wild_Card Unit'
    assert_not_includes names, 'WildxCard Unit'
  end

  # issue #1277: keyが空のUnitが混ざっていても、公開側の一覧ページ(UnitCardComponent)が
  # profile_path(key)のUrlGenerationErrorで落ちないことを保険的に確認する
  test 'index still renders when a unit has a blank key' do
    Unit.new(name: 'Legacy Blank Key Unit', status: :active).save(validate: false)

    get units_path

    assert_response :success
  end

  # issue #1764
  test 'index, search and show exclude provisional units' do
    Unit.create!(name: 'Hidden Provisional Band', name_kana: 'ヒドゥン', key: 'hidden-provisional-band', provisional: true)

    get units_path(q: 'Hidden Provisional')
    assert_not_includes response.body, 'Hidden Provisional Band'

    get search_units_path(q: 'Hidden Provisional')
    assert_empty response.parsed_body

    get unit_path('hidden-provisional-band', format: :json)
    assert_response :not_found
  end

  # issue #1855: 一覧ページの検索は名前系の列だけを探す。セクション名・メンバー名で探すのは /search だけ
  test 'index does not search snapshot member names' do
    unit = Unit.create!(name: 'IndexMemberNameMatchUnit', key: 'index-member-name-match-unit-test', status: :active)
    snapshot = unit.unit_snapshots.create!(active: true)
    snapshot.snapshot_people.create!(person_name: 'UniqueIndexSnapshotMemberNameTest', status: :left)

    get units_path(q: 'UniqueIndexSnapshotMemberNameTest')

    assert_response :success
    assert_not_includes response.body, 'IndexMemberNameMatchUnit'
  end

  test 'index does not search section names' do
    unit = Unit.create!(name: 'IndexSectionMatchUnit', key: 'index-section-match-unit-test', status: :active)
    unit.sections.create!(name: 'UniqueIndexSectionNameForUnitTest', active: true)

    get units_path(q: 'UniqueIndexSectionNameForUnitTest')

    assert_response :success
    assert_not_includes response.body, 'IndexSectionMatchUnit'
  end

  test 'index finds a unit by a former name and an alias' do
    Unit.create!(name: 'IndexFormerNameUnit', key: 'index-former-name-unit-test', status: :active,
                 name_log: [{ name: 'UniqueIndexFormerUnitName' }], aliases_attributes: { '0' => { 'name' => 'UniqueIndexUnitAlias' } })

    get units_path(q: 'UniqueIndexFormerUnitName')
    assert_includes response.body, 'IndexFormerNameUnit'

    get units_path(q: 'UniqueIndexUnitAlias')
    assert_includes response.body, 'IndexFormerNameUnit'
  end
end
