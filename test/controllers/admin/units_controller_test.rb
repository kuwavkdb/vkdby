# frozen_string_literal: true

require 'test_helper'

module Admin
  class UnitsControllerTest < ActionDispatch::IntegrationTest # rubocop:disable Metrics/ClassLength
    setup do
      post login_path, params: { email: users(:one).email, password: 'password' }
      @unit = Unit.create!(name: 'Existing Unit', key: 'existing-unit-controller-test', status: :active)
    end

    test 'update does not change key even when key param is submitted' do
      patch admin_unit_path(@unit), params: {
        unit: { name: 'Renamed Unit', key: 'attempted-new-key' }
      }

      assert_redirected_to edit_admin_unit_path(@unit)
      @unit.reload
      assert_equal 'existing-unit-controller-test', @unit.key
      assert_equal 'Renamed Unit', @unit.name
    end

    test 'create allows setting key' do
      assert_difference('Unit.count') do
        post admin_units_path, params: {
          unit: { name: 'Brand New Unit', key: 'brand-new-unit-key', status: 'active' }
        }
      end

      assert_equal 'brand-new-unit-key', Unit.last.key
    end

    test 'change_key requires admin role' do
      patch change_key_admin_unit_path(@unit), params: { new_key: 'attempted-new-key' }

      assert_redirected_to root_path
      assert_equal 'existing-unit-controller-test', @unit.reload.key
    end

    test 'change_key updates the key and creates a redirect stub when admin' do
      login_as_admin

      patch change_key_admin_unit_path(@unit), params: { new_key: 'new-unit-key-via-endpoint' }

      assert_redirected_to edit_admin_unit_path(@unit)
      assert_nil flash[:alert]
      assert_equal 'Key changed successfully.', flash[:notice]
      assert_equal 'new-unit-key-via-endpoint', @unit.reload.key
      stub = Unit.discarded.find_by(key: 'existing-unit-controller-test')
      assert stub.present?
      assert_equal 'new-unit-key-via-endpoint', stub.destination_key
      assert UpdateLog.exists?(loggable: @unit, action: 'change_key')
    end

    test 'change_key shows an error when the new key is already taken' do
      login_as_admin
      Unit.create!(name: 'Other Unit', key: 'already-taken-key', status: :active)

      patch change_key_admin_unit_path(@unit), params: { new_key: 'already-taken-key' }

      assert_redirected_to edit_admin_unit_path(@unit)
      assert_equal 'existing-unit-controller-test', @unit.reload.key
    end

    test 'purge requires admin role' do
      @unit.change_key!('new-key-for-purge-auth-test')
      stub = Unit.discarded.find_by(key: 'existing-unit-controller-test')

      delete purge_admin_unit_path(stub)

      assert_redirected_to root_path
      assert Unit.exists?(id: stub.id)
    end

    test 'purge is rejected for a non redirect-source record' do
      login_as_admin

      delete purge_admin_unit_path(@unit)

      assert_redirected_to admin_units_path(redirect_source: 'only')
      assert_equal 'リダイレクト元のレコードのみ物理削除できます。', flash[:alert]
      assert Unit.exists?(id: @unit.id)
    end

    test 'purge deletes the redirect-source stub and logs the action' do
      login_as_admin
      @unit.change_key!('new-key-for-purge-test')
      stub = Unit.discarded.find_by(key: 'existing-unit-controller-test')

      delete purge_admin_unit_path(stub)

      assert_redirected_to admin_units_path(redirect_source: 'only')
      assert_equal 'リダイレクト元レコードを物理削除しました。', flash[:notice]
      assert_not Unit.exists?(id: stub.id)
      assert UpdateLog.exists?(loggable_type: 'Unit', loggable_id: stub.id, action: 'purge')
    end

    test 'purge is rejected when the key is still referenced by an item' do
      login_as_admin
      @unit.change_key!('new-key-for-purge-item-test')
      stub = Unit.discarded.find_by(key: 'existing-unit-controller-test')
      Item.create!(title: 'Some Album', release_date: Date.current, link_url: 'https://example.com/item',
                   artists: [{ 'key' => stub.key, 'name' => 'Existing Unit' }])

      delete purge_admin_unit_path(stub)

      assert_redirected_to admin_units_path(redirect_source: 'only')
      assert_equal 'このキーはまだ作品から参照されているため物理削除できません。', flash[:alert]
      assert Unit.exists?(id: stub.id)
    end

    test 'purging a redirect-source stub allows reverting the key' do
      login_as_admin
      @unit.change_key!('new-key-for-purge-revert-test')
      stub = Unit.discarded.find_by(key: 'existing-unit-controller-test')

      delete purge_admin_unit_path(stub)
      @unit.reload.change_key!('existing-unit-controller-test')

      assert_equal 'existing-unit-controller-test', @unit.reload.key
    end

    test 'edit shows the change key form for admin' do
      login_as_admin

      get edit_admin_unit_path(@unit)

      assert_response :success
      assert_includes response.body, 'キー変更'
    end

    test 'edit does not show the change key form for non-admin' do
      get edit_admin_unit_path(@unit)

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
