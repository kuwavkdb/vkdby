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
end
