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

    test 'should get copy_to_unit form' do
      get copy_to_unit_admin_unit_unit_snapshot_path(@unit, @snapshot)
      assert_response :success
    end

    test 'should copy unit_snapshot to another unit' do
      other_unit = units(:two)

      assert_difference('UnitSnapshot.count', 1) do
        assert_difference('SnapshotPerson.count', @snapshot.snapshot_people.count) do
          post copy_to_unit_admin_unit_unit_snapshot_path(@unit, @snapshot), params: { target_unit_id: other_unit.id }
        end
      end

      new_snapshot = UnitSnapshot.last
      assert_equal other_unit, new_snapshot.unit
      assert_equal @snapshot.label, new_snapshot.label
      assert_not new_snapshot.current?
      assert_redirected_to edit_admin_unit_unit_snapshot_path(other_unit, new_snapshot)
    end

    test 'should not copy unit_snapshot when target unit is missing' do
      assert_no_difference('UnitSnapshot.count') do
        post copy_to_unit_admin_unit_unit_snapshot_path(@unit, @snapshot), params: { target_unit_id: '' }
      end
      assert_redirected_to copy_to_unit_admin_unit_unit_snapshot_path(@unit, @snapshot)
    end

    test 'should reorder unit_snapshots' do
      other_snapshot = unit_snapshots(:two)

      patch reorder_admin_unit_unit_snapshots_path(@unit), params: {
        ids: [other_snapshot.id, @snapshot.id]
      }, as: :json

      assert_response :success
      assert_equal 1, other_snapshot.reload.snapshot_index
      assert_equal 2, @snapshot.reload.snapshot_index
    end

    test 'should redirect to login when not authenticated' do
      delete logout_path
      get admin_unit_unit_snapshots_path(@unit)
      assert_redirected_to login_path
    end
  end
end
