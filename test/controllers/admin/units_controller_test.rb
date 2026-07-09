# frozen_string_literal: true

require 'test_helper'

module Admin
  class UnitsControllerTest < ActionDispatch::IntegrationTest
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
  end
end
