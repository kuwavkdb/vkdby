# frozen_string_literal: true

require 'test_helper'

class SearchControllerTest < ActionDispatch::IntegrationTest
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
    # ユニット名を検索クエリと同じ部分文字列("DiscardedSection"等)を含めないようにする。
    # あいまい検索(trigram類似度)は共通の部分文字列があるとそれだけでヒットしてしまうため、
    # 「discard済みSectionが除外されていること」を確認するにはユニット名自体を無関係にする必要がある。
    unit = Unit.create!(name: 'DiscardExcludedUnit', key: 'discarded-section-unit-test', status: :active)
    section = unit.sections.create!(name: 'UniqueDiscardedSectionNameTest', active: true)
    section.discard!

    get search_path(q: 'UniqueDiscardedSectionNameTest')

    assert_response :success
    assert_not_includes response.body, 'DiscardExcludedUnit'
  end

  test 'index does not find a unit via an inactive (non-public) section name' do
    # ユニット名を検索クエリと同じ部分文字列("InactiveSection"等)を含めないようにする。理由は上記と同様。
    unit = Unit.create!(name: 'InactiveExcludedUnit', key: 'inactive-section-unit-test', status: :active)
    unit.sections.create!(name: 'UniqueInactiveSectionNameTest', active: false)

    get search_path(q: 'UniqueInactiveSectionNameTest')

    assert_response :success
    assert_not_includes response.body, 'InactiveExcludedUnit'
  end

  # SEARCH_BACKEND=legacy 指定時、pg_search移行前のILIKEベースの検索にコード変更なしで
  # 戻せることを確認する（issue #1536。問題発生時の当面のロールバック手段）。
  test 'index falls back to the legacy ILIKE search when SEARCH_BACKEND is legacy' do
    Unit.create!(name: 'LegacyBackendUnit', key: 'legacy-backend-unit-test', status: :active)
    Person.create!(name: 'LegacyBackendPerson', key: 'legacy-backend-person-test', status: :active)
    page = CustomPage.create!(key: 'legacy-backend-page-test', title: 'Legacy Backend Page', body: 'body', active: true)

    with_search_backend('legacy') do
      get search_path(q: 'LegacyBackendUnit')
      assert_response :success
      assert_includes response.body, 'LegacyBackendUnit'

      get search_path(q: 'LegacyBackendPerson')
      assert_response :success
      assert_includes response.body, 'LegacyBackendPerson'

      get search_path(q: 'Legacy Backend Page')
      assert_response :success
      assert_includes response.body, custom_page_path(page.key)
    end
  end

  private

  def with_search_backend(backend)
    original = Rails.application.config.search_backend
    Rails.application.config.search_backend = backend
    yield
  ensure
    Rails.application.config.search_backend = original
  end
end
