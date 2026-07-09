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

    test 'change_key requires admin role' do
      patch change_key_admin_person_path(@person), params: { new_key: 'attempted-new-key' }

      assert_redirected_to root_path
      assert_equal 'existing-person-controller-test', @person.reload.key
    end

    test 'change_key updates the key and creates a redirect stub when admin' do
      login_as_admin

      patch change_key_admin_person_path(@person), params: { new_key: 'new-person-key-via-endpoint' }

      assert_redirected_to edit_admin_person_path(@person)
      assert_nil flash[:alert]
      assert_equal 'Key changed successfully.', flash[:notice]
      assert_equal 'new-person-key-via-endpoint', @person.reload.key
      stub = Person.discarded.find_by(key: 'existing-person-controller-test')
      assert stub.present?
      assert_equal 'new-person-key-via-endpoint', stub.destination_key
      assert UpdateLog.exists?(loggable: @person, action: 'change_key')
    end

    test 'change_key shows an error when the new key is already taken' do
      login_as_admin
      Person.create!(name: 'Other Person', key: 'already-taken-person-key', status: :active)

      patch change_key_admin_person_path(@person), params: { new_key: 'already-taken-person-key' }

      assert_redirected_to edit_admin_person_path(@person)
      assert_equal 'existing-person-controller-test', @person.reload.key
    end

    test 'edit shows the change key form for admin' do
      login_as_admin

      get edit_admin_person_path(@person)

      assert_response :success
      assert_includes response.body, 'キー変更'
    end

    test 'edit does not show the change key form for non-admin' do
      get edit_admin_person_path(@person)

      assert_response :success
      assert_not_includes response.body, 'キー変更'
    end

    private

    def login_as_admin
      admin = User.create!(email: 'admin-key-change-test@example.com', name: 'Admin', password: 'password', role: :admin)
      post login_path, params: { email: admin.email, password: 'password' }
    end
  end
end
