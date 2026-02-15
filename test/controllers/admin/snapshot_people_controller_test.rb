# frozen_string_literal: true

require 'test_helper'

module Admin
  class SnapshotPeopleControllerTest < ActionDispatch::IntegrationTest
    setup do
      post login_path, params: { email: users(:one).email, password: 'password' }
      @unit = units(:one)
      @snapshot = unit_snapshots(:one)
    end

    test 'should create snapshot_person with person' do
      assert_difference('SnapshotPerson.count') do
        post admin_unit_unit_snapshot_snapshot_people_path(@unit, @snapshot), params: {
          snapshot_person: { person_id: people(:one).id, part: 'Vo.', sort_order: 10 }
        }
      end
      assert_redirected_to edit_admin_unit_unit_snapshot_path(@unit, @snapshot)
    end

    test 'should create snapshot_person with person_name' do
      assert_difference('SnapshotPerson.count') do
        post admin_unit_unit_snapshot_snapshot_people_path(@unit, @snapshot), params: {
          snapshot_person: { person_name: 'New Member', part: 'Ba.', sort_order: 5 }
        }
      end
      assert_redirected_to edit_admin_unit_unit_snapshot_path(@unit, @snapshot)
    end

    test 'should not create snapshot_person without part' do
      assert_no_difference('SnapshotPerson.count') do
        post admin_unit_unit_snapshot_snapshot_people_path(@unit, @snapshot), params: {
          snapshot_person: { person_name: 'Invalid', part: '', sort_order: 1 }
        }
      end
      assert_redirected_to edit_admin_unit_unit_snapshot_path(@unit, @snapshot)
    end

    test 'should destroy snapshot_person' do
      sp = snapshot_people(:one)
      assert_difference('SnapshotPerson.count', -1) do
        delete admin_unit_unit_snapshot_snapshot_person_path(@unit, @snapshot, sp)
      end
      assert_redirected_to edit_admin_unit_unit_snapshot_path(@unit, @snapshot)
    end
  end
end
