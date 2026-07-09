# frozen_string_literal: true

require 'test_helper'

module Admin
  class PeopleControllerTest < ActionDispatch::IntegrationTest
    setup do
      post login_path, params: { email: users(:one).email, password: 'password' }
      @person = Person.create!(name: 'Existing Person', key: 'existing-person-controller-test', status: :active)
    end

    test 'create allows setting key' do
      assert_difference('Person.count') do
        post admin_people_path, params: {
          person: { name: 'Brand New Person', key: 'brand-new-person-key', status: 'active' }
        }
      end

      assert_equal 'brand-new-person-key', Person.last.key
    end

    test 'update does not change key even when key param is submitted' do
      patch admin_person_path(@person), params: {
        person: { name: 'Renamed Person', key: 'attempted-new-key' }
      }

      assert_redirected_to edit_admin_person_path(@person)
      @person.reload
      assert_equal 'existing-person-controller-test', @person.key
      assert_equal 'Renamed Person', @person.name
    end
  end
end
