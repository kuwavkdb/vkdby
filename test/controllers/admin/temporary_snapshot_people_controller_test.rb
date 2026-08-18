# frozen_string_literal: true

require 'test_helper'

module Admin
  class TemporarySnapshotPeopleControllerTest < ActionDispatch::IntegrationTest
    setup do
      post login_path, params: { email: users(:one).email, password: 'password' }
      @unit = units(:one)
      @snapshot = unit_snapshots(:one)
      @temporary_snapshot_person = TemporarySnapshotPerson.create!(
        person_name: 'テスト太郎',
        part: :vocal,
        status: :left,
        hint_unit: @unit
      )
    end

    test 'should get index' do
      get admin_temporary_snapshot_people_path
      assert_response :success
    end

    test 'should get index filtered by unit' do
      get admin_temporary_snapshot_people_path(unit_id: @unit.id)
      assert_response :success
      assert_match @temporary_snapshot_person.name, response.body
    end

    test 'should get assign form defaulting to hint unit' do
      get assign_admin_temporary_snapshot_person_path(@temporary_snapshot_person)
      assert_response :success
      assert_match @unit.name, response.body
    end

    test 'should assign to an existing snapshot and remove from pool' do
      assert_difference('SnapshotPerson.count', 1) do
        assert_difference('TemporarySnapshotPerson.count', -1) do
          post assign_admin_temporary_snapshot_person_path(@temporary_snapshot_person), params: {
            unit_id: @unit.id,
            unit_snapshot_id: @snapshot.id,
            part: 'vocal',
            status: 'left'
          }
        end
      end

      assert_redirected_to admin_temporary_snapshot_people_path(
        assigned_unit_id: @unit.id, assigned_unit_snapshot_id: @snapshot.id
      )
      assert_equal 'テスト太郎', @snapshot.reload.snapshot_people.last.person_name
    end

    test 'should show a link to the assigned unit snapshot after assigning' do
      post assign_admin_temporary_snapshot_person_path(@temporary_snapshot_person), params: {
        unit_id: @unit.id,
        unit_snapshot_id: @snapshot.id,
        part: 'vocal',
        status: 'left'
      }
      follow_redirect!

      assert_response :success
      assert_select "a[href='#{edit_admin_unit_unit_snapshot_path(@unit, @snapshot)}']"
    end

    test 'should assign to a newly created snapshot when none selected' do
      assert_difference('UnitSnapshot.count', 1) do
        post assign_admin_temporary_snapshot_person_path(@temporary_snapshot_person), params: {
          unit_id: @unit.id,
          unit_snapshot_id: '',
          part: 'vocal',
          status: 'left'
        }
      end

      assert_redirected_to admin_temporary_snapshot_people_path(
        assigned_unit_id: @unit.id, assigned_unit_snapshot_id: UnitSnapshot.last.id
      )
    end

    test 'should not assign without a target unit' do
      unhinted = TemporarySnapshotPerson.create!(person_name: 'ヒントなし', part: :vocal, status: :left)

      assert_no_difference('SnapshotPerson.count') do
        post assign_admin_temporary_snapshot_person_path(unhinted), params: { unit_id: '' }
      end
      assert_redirected_to assign_admin_temporary_snapshot_person_path(unhinted)
    end

    test 'should destroy pooled entry' do
      assert_difference('TemporarySnapshotPerson.count', -1) do
        delete admin_temporary_snapshot_person_path(@temporary_snapshot_person)
      end
      assert_redirected_to admin_temporary_snapshot_people_path
    end

    test 'should redirect to login when not authenticated' do
      delete logout_path
      get admin_temporary_snapshot_people_path
      assert_redirected_to login_path
    end
  end
end
