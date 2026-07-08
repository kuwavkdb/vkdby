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
end
