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
          snapshot_person: { person_id: people(:one).id, part: 'vocal', sort_order: 10 }
        }
      end
      assert_redirected_to edit_admin_unit_unit_snapshot_path(@unit, @snapshot)
    end

    test 'should create snapshot_person with person_name' do
      assert_difference('SnapshotPerson.count') do
        post admin_unit_unit_snapshot_snapshot_people_path(@unit, @snapshot), params: {
          snapshot_person: { person_name: 'New Member', part: 'bass', sort_order: 5 }
        }
      end
      assert_redirected_to edit_admin_unit_unit_snapshot_path(@unit, @snapshot)
    end

    test 'should not create snapshot_person without part' do
      assert_no_difference('SnapshotPerson.count') do
        post admin_unit_unit_snapshot_snapshot_people_path(@unit, @snapshot), params: {
          snapshot_person: { person_name: 'Invalid', part: nil, sort_order: 1 }
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

    test 'should create person and link when person_key is new' do
      sp = @snapshot.snapshot_people.create!(person_name: 'New Guy', part: 'vocal', person_key: 'new_test_key')

      assert_difference('Person.count', 1) do
        post create_person_admin_unit_unit_snapshot_snapshot_person_path(@unit, @snapshot, sp)
      end

      sp.reload
      assert_equal 'new_test_key', sp.person.key
      assert_equal 'New Guy', sp.person.name
      assert_redirected_to edit_admin_unit_unit_snapshot_snapshot_person_path(@unit, @snapshot, sp)
    end

    test 'should not create person when person_key is blank' do
      sp = @snapshot.snapshot_people.create!(person_name: 'No Key Guy', part: 'vocal')

      assert_no_difference('Person.count') do
        post create_person_admin_unit_unit_snapshot_snapshot_person_path(@unit, @snapshot, sp)
      end

      sp.reload
      assert_nil sp.person_id
      assert_redirected_to edit_admin_unit_unit_snapshot_snapshot_person_path(@unit, @snapshot, sp)
    end

    test 'should not create person when already linked' do
      sp = @snapshot.snapshot_people.create!(
        person_name: 'Linked Guy', part: 'vocal', person_id: people(:one).id, person_key: 'linked_key'
      )

      assert_no_difference('Person.count') do
        post create_person_admin_unit_unit_snapshot_snapshot_person_path(@unit, @snapshot, sp)
      end

      assert_redirected_to edit_admin_unit_unit_snapshot_snapshot_person_path(@unit, @snapshot, sp)
    end

    test 'should link to existing person when person_key is already in use' do
      Person.create!(name: 'Existing', key: 'dup_key')
      sp = @snapshot.snapshot_people.create!(person_name: 'Dup Guy', part: 'vocal')
      sp.update_column(:person_key, 'dup_key')

      assert_no_difference('Person.count') do
        post create_person_admin_unit_unit_snapshot_snapshot_person_path(@unit, @snapshot, sp)
      end

      sp.reload
      assert_nil sp.person_id
      assert_redirected_to edit_admin_unit_unit_snapshot_snapshot_person_path(@unit, @snapshot, sp)
    end
  end
end
