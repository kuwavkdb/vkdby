# frozen_string_literal: true

require 'test_helper'

module Admin
  class UnitSnapshotsControllerTest < ActionDispatch::IntegrationTest
    setup do
      post login_path, params: { email: users(:one).email, password: 'password' }
      @unit = units(:one)
      @snapshot = unit_snapshots(:one)
    end

    test 'should get index' do
      get admin_unit_unit_snapshots_path(@unit)
      assert_response :success
    end

    test 'should get new' do
      get new_admin_unit_unit_snapshot_path(@unit)
      assert_response :success
    end

    test 'should create unit_snapshot' do
      assert_difference('UnitSnapshot.count') do
        post admin_unit_unit_snapshots_path(@unit), params: {
          unit_snapshot: { snapshot_date: '2025-01-01', label: 'Test', current: false }
        }
      end
      assert_redirected_to edit_admin_unit_unit_snapshot_path(@unit, UnitSnapshot.last)
    end

    test 'should not create unit_snapshot with duplicate date' do
      assert_no_difference('UnitSnapshot.count') do
        post admin_unit_unit_snapshots_path(@unit), params: {
          unit_snapshot: { snapshot_date: @snapshot.snapshot_date, label: 'Duplicate' }
        }
      end
      assert_response :unprocessable_entity
    end

    test 'should get edit' do
      get edit_admin_unit_unit_snapshot_path(@unit, @snapshot)
      assert_response :success
    end

    test 'should update unit_snapshot' do
      patch admin_unit_unit_snapshot_path(@unit, @snapshot), params: {
        unit_snapshot: { label: 'Updated Label' }
      }
      assert_redirected_to admin_unit_unit_snapshots_path(@unit)
      @snapshot.reload
      assert_equal 'Updated Label', @snapshot.label
    end

    test 'should destroy unit_snapshot' do
      assert_difference('UnitSnapshot.count', -1) do
        delete admin_unit_unit_snapshot_path(@unit, @snapshot)
      end
      assert_redirected_to admin_unit_unit_snapshots_path(@unit)
    end

    test 'should redirect to login when not authenticated' do
      delete logout_path
      get admin_unit_unit_snapshots_path(@unit)
      assert_redirected_to login_path
    end
  end
end
