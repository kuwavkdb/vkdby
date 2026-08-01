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
end
