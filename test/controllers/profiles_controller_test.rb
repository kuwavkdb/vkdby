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
end
