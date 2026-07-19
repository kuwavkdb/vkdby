# frozen_string_literal: true

require 'test_helper'

class ItemsControllerTest < ActionDispatch::IntegrationTest
  test 'index does not resolve artist info for a discarded unit key' do
    unit = Unit.create!(name: 'Discarded Unit', key: 'discarded-unit-items-test', status: :active)
    unit.discard

    get items_path(key: unit.key)

    assert_response :success
    assert_not_includes response.body, 'Discarded Unit'
  end

  test 'index does not resolve artist info for a discarded person key' do
    person = Person.create!(name: 'Discarded Person', key: 'discarded-person-items-test', status: :active)
    person.discard

    get items_path(key: person.key)

    assert_response :success
    assert_not_includes response.body, 'Discarded Person'
  end

  test 'index resolves artist info for a kept unit key' do
    unit = Unit.create!(name: 'Kept Unit', key: 'kept-unit-items-test', status: :active)

    get items_path(key: unit.key)

    assert_response :success
    assert_includes response.body, 'Kept Unit'
  end

  test 'index filters by title with q param' do
    get items_path(q: 'Item One')

    assert_response :success
    assert_includes response.body, 'Item One'
    assert_not_includes response.body, 'Item Two'
  end

  test 'index filters by artist name with q param' do
    item = Item.create!(
      title: 'Searchable Artist Item',
      artists: [{ 'name' => 'Unique Artist Name' }],
      release_date: '2026-03-01',
      link_url: 'http://example.com/searchable-artist-item'
    )

    get items_path(q: 'Unique Artist Name')

    assert_response :success
    assert_includes response.body, item.title
    assert_not_includes response.body, 'Item One'
  end
end
