# frozen_string_literal: true

require 'test_helper'

module Admin
  class PeopleControllerTest < ActionDispatch::IntegrationTest # rubocop:disable Metrics/ClassLength
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

    test 'purge requires admin role' do
      @person.change_key!('new-key-for-purge-auth-test')
      stub = Person.discarded.find_by(key: 'existing-person-controller-test')

      delete purge_admin_person_path(stub)

      assert_redirected_to root_path
      assert Person.exists?(id: stub.id)
    end

    test 'purge is rejected for a non redirect-source record' do
      login_as_admin

      delete purge_admin_person_path(@person)

      assert_redirected_to admin_people_path(redirect_source: 'only')
      assert_equal 'リダイレクト元のレコードのみ物理削除できます。', flash[:alert]
      assert Person.exists?(id: @person.id)
    end

    test 'purge deletes the redirect-source stub and logs the action' do
      login_as_admin
      @person.change_key!('new-key-for-purge-test')
      stub = Person.discarded.find_by(key: 'existing-person-controller-test')

      delete purge_admin_person_path(stub)

      assert_redirected_to admin_people_path(redirect_source: 'only')
      assert_equal 'リダイレクト元レコードを物理削除しました。', flash[:notice]
      assert_not Person.exists?(id: stub.id)
      assert UpdateLog.exists?(loggable_type: 'Person', loggable_id: stub.id, action: 'purge')
    end

    test 'purge is rejected when the key is still referenced by an item' do
      login_as_admin
      @person.change_key!('new-key-for-purge-item-test')
      stub = Person.discarded.find_by(key: 'existing-person-controller-test')
      Item.create!(title: 'Some Album', release_date: Date.current, link_url: 'https://example.com/item',
                   artists: [{ 'key' => stub.key, 'name' => 'Existing Person' }])

      delete purge_admin_person_path(stub)

      assert_redirected_to admin_people_path(redirect_source: 'only')
      assert_equal 'このキーはまだ作品から参照されているため物理削除できません。', flash[:alert]
      assert Person.exists?(id: stub.id)
    end

    test 'purging a redirect-source stub allows reverting the key' do
      login_as_admin
      @person.change_key!('new-key-for-purge-revert-test')
      stub = Person.discarded.find_by(key: 'existing-person-controller-test')

      delete purge_admin_person_path(stub)
      @person.reload.change_key!('existing-person-controller-test')

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
