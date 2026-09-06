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
end
