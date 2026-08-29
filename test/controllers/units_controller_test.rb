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

  # issue #1277: keyが空のUnitが混ざっていても、公開側の一覧ページ(UnitCardComponent)が
  # profile_path(key)のUrlGenerationErrorで落ちないことを保険的に確認する
  test 'index still renders when a unit has a blank key' do
    Unit.new(name: 'Legacy Blank Key Unit', status: :active).save(validate: false)

    get units_path

    assert_response :success
  end
end
