# frozen_string_literal: true

require 'test_helper'

class SearchControllerTest < ActionDispatch::IntegrationTest # rubocop:disable Metrics/ClassLength
  test 'index finds a unit whose name is half-width when queried with full-width alphanumerics' do
    Unit.create!(name: 'ABC123', key: 'zenkaku-search-unit-test', status: :active)

    get search_path(q: 'ＡＢＣ１２３')

    assert_response :success
    assert_includes response.body, 'ABC123'
  end

  test 'index finds a person whose name is half-width when queried with full-width alphanumerics' do
    Person.create!(name: 'XYZ789', key: 'zenkaku-search-person-test', status: :active)

    get search_path(q: 'ＸＹＺ７８９')

    assert_response :success
    assert_includes response.body, 'XYZ789'
  end

  test 'index finds a published custom page by title' do
    page = CustomPage.create!(key: 'search-target-page-test', title: 'Search Target Page', body: 'body', active: true)

    get search_path(q: 'Search Target Page')

    assert_response :success
    assert_includes response.body, custom_page_path(page.key)
  end

  test 'index does not find an unpublished custom page' do
    page = CustomPage.create!(key: 'unpublished-search-page-test', title: 'Unpublished Search Page', body: 'body', active: false)

    get search_path(q: 'Unpublished Search Page')

    assert_response :success
    assert_not_includes response.body, custom_page_path(page.key)
  end

  test 'index does not find a system page' do
    page = CustomPage.find_or_create_by!(key: 'footer') { |p| p.title = 'Footer System Page' }
    page.update!(title: 'Footer System Page', body: 'body', active: true)

    get search_path(q: 'Footer System Page')

    assert_response :success
    assert_not_includes response.body, custom_page_path(page.key)
  end

  test 'index shows the inline Google custom search widget when nothing matches' do
    get search_path(q: 'no-such-result-search-controller-test')

    assert_response :success
    assert_includes response.body, '検索結果が見つかりませんでした'
    assert_includes response.body, '<div class="gcse-search">'
    assert_match(%r{cse\.google\.com/cse\.js\?cx=}, response.body)
    assert_match(/window\.location\.hash = "gsc\.tab=0&gsc\.q=no-such-result-search-controller-test&gsc\.sort="/, response.body)
  end

  test 'index also shows the inline Google custom search widget when there are results' do
    Unit.create!(name: 'HasResultUnit', key: 'has-result-unit-search-test', status: :active)

    get search_path(q: 'HasResultUnit')

    assert_response :success
    assert_includes response.body, 'HasResultUnit'
    assert_includes response.body, '<div class="gcse-search">'
    assert_match(%r{cse\.google\.com/cse\.js\?cx=}, response.body)
    assert_match(/window\.location\.hash = "gsc\.tab=0&gsc\.q=HasResultUnit&gsc\.sort="/, response.body)
  end

  test 'index finds a unit via a linked section name' do
    unit = Unit.create!(name: 'SectionMatchUnit', key: 'section-match-unit-test', status: :active)
    unit.sections.create!(name: 'UniqueSectionNameForUnitTest', active: true)

    get search_path(q: 'UniqueSectionNameForUnitTest')

    assert_response :success
    assert_includes response.body, 'SectionMatchUnit'
  end

  test 'index finds a person via a linked section name' do
    person = Person.create!(name: 'SectionMatchPerson', key: 'section-match-person-test', status: :active)
    person.sections.create!(name: 'UniqueSectionNameForPersonTest', active: true)

    get search_path(q: 'UniqueSectionNameForPersonTest')

    assert_response :success
    assert_includes response.body, 'SectionMatchPerson'
  end

  test 'index finds a custom page via a linked section name' do
    page = CustomPage.create!(key: 'section-match-page-test', title: 'Section Match Page', body: 'body', active: true)
    page.sections.create!(name: 'UniqueSectionNameForPageTest', active: true)

    get search_path(q: 'UniqueSectionNameForPageTest')

    assert_response :success
    assert_includes response.body, custom_page_path(page.key)
  end

  test 'index does not find a unit via a discarded section name' do
    unit = Unit.create!(name: 'DiscardedSectionUnit', key: 'discarded-section-unit-test', status: :active)
    section = unit.sections.create!(name: 'UniqueDiscardedSectionNameTest', active: true)
    section.discard!

    get search_path(q: 'UniqueDiscardedSectionNameTest')

    assert_response :success
    assert_not_includes response.body, 'DiscardedSectionUnit'
  end

  test 'index does not find a unit via an inactive (non-public) section name' do
    unit = Unit.create!(name: 'InactiveSectionUnit', key: 'inactive-section-unit-test', status: :active)
    unit.sections.create!(name: 'UniqueInactiveSectionNameTest', active: false)

    get search_path(q: 'UniqueInactiveSectionNameTest')

    assert_response :success
    assert_not_includes response.body, 'InactiveSectionUnit'
  end

  test 'index finds a unit via a snapshot member name without a person page' do
    unit = Unit.create!(name: 'MemberNameMatchUnit', key: 'member-name-match-unit-test', status: :active)
    snapshot = unit.unit_snapshots.create!(active: true)
    snapshot.snapshot_people.create!(person_name: 'UniqueSnapshotMemberNameTest', status: :left)

    get search_path(q: 'UniqueSnapshotMemberNameTest')

    assert_response :success
    assert_includes response.body, 'MemberNameMatchUnit'
  end

  test 'index finds a unit via a snapshot member name alias' do
    unit = Unit.create!(name: 'MemberAliasMatchUnit', key: 'member-alias-match-unit-test', status: :active)
    snapshot = unit.unit_snapshots.create!(active: true)
    snapshot.snapshot_people.create!(person_name: 'SomeMember', name_alias: 'UniqueSnapshotNameAliasTest')

    get search_path(q: 'UniqueSnapshotNameAliasTest')

    assert_response :success
    assert_includes response.body, 'MemberAliasMatchUnit'
  end

  test 'index does not find a unit via a discarded snapshot member name' do
    unit = Unit.create!(name: 'DiscardedMemberUnit', key: 'discarded-member-unit-test', status: :active)
    snapshot = unit.unit_snapshots.create!(active: true)
    snapshot.snapshot_people.create!(person_name: 'UniqueDiscardedMemberNameTest').discard!

    get search_path(q: 'UniqueDiscardedMemberNameTest')

    assert_response :success
    assert_not_includes response.body, 'DiscardedMemberUnit'
  end

  test 'index does not find a unit via a member of an inactive snapshot' do
    unit = Unit.create!(name: 'InactiveSnapshotUnit', key: 'inactive-snapshot-unit-test', status: :active)
    snapshot = unit.unit_snapshots.create!(active: false)
    snapshot.snapshot_people.create!(person_name: 'UniqueInactiveSnapshotMemberTest')

    get search_path(q: 'UniqueInactiveSnapshotMemberTest')

    assert_response :success
    assert_not_includes response.body, 'InactiveSnapshotUnit'
  end

  test 'index does not find a provisional unit via a snapshot member name' do
    unit = Unit.create!(name: 'ProvisionalMemberUnit', key: 'provisional-member-unit-test', status: :active, provisional: true)
    snapshot = unit.unit_snapshots.create!(active: true)
    snapshot.snapshot_people.create!(person_name: 'UniqueProvisionalMemberNameTest')

    get search_path(q: 'UniqueProvisionalMemberNameTest')

    assert_response :success
    assert_not_includes response.body, 'ProvisionalMemberUnit'
  end
end
