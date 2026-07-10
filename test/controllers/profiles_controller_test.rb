# frozen_string_literal: true

require 'test_helper'

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test 'should show unit with dot in key' do
    unit = Unit.create!(name: 'Sick.', key: 'sick.', old_key: 'Sick.', status: :active)
    get profile_path(unit.key)
    assert_response :success
  end

  test 'should show person with dot in key' do
    person = Person.create!(name: 'Mr.Dot', key: 'mr.dot', old_key: 'Mr.Dot', status: :active)
    get profile_path(person.key)
    assert_response :success
  end

  test 'accessing a unit by its previous key redirects to the current key after change_key!' do
    unit = Unit.create!(name: 'Renamed Unit', key: 'unit-redirect-before', status: :active)
    unit.change_key!('unit-redirect-after')

    get profile_path('unit-redirect-before')

    assert_response :moved_permanently
    assert_redirected_to profile_path('unit-redirect-after')

    follow_redirect!
    assert_response :success
    assert_includes response.body, 'Renamed Unit'
  end

  test 'accessing a person by its previous key redirects to the current key after change_key!' do
    person = Person.create!(name: 'Renamed Person', key: 'person-redirect-before', status: :active)
    person.change_key!('person-redirect-after')

    get profile_path('person-redirect-before')

    assert_response :moved_permanently
    assert_redirected_to profile_path('person-redirect-after')

    follow_redirect!
    assert_response :success
    assert_includes response.body, 'Renamed Person'
  end

  test 'accessing a key renamed twice requires two redirect hops to reach the final key' do
    unit = Unit.create!(name: 'Twice Renamed Unit', key: 'unit-chain-a', status: :active)
    unit.change_key!('unit-chain-b')
    unit.change_key!('unit-chain-c')

    get profile_path('unit-chain-a')
    assert_response :moved_permanently
    assert_redirected_to profile_path('unit-chain-b')

    follow_redirect!
    assert_response :moved_permanently
    assert_redirected_to profile_path('unit-chain-c')

    follow_redirect!
    assert_response :success
    assert_includes response.body, 'Twice Renamed Unit'
  end
end
