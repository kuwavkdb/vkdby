# frozen_string_literal: true

require 'test_helper'

module Admin
  class SnapshotPeopleControllerTest < ActionDispatch::IntegrationTest # rubocop:disable Metrics/ClassLength
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

    test 'should ignore name_alias param and not persist it via person_name field' do
      sp = @snapshot.snapshot_people.create!(person_name: 'Original Name', part: 'vocal')

      patch admin_unit_unit_snapshot_snapshot_person_path(@unit, @snapshot, sp), params: {
        snapshot_person: { person_name: 'Original Name', part: sp.part, sort_order: sp.sort_order, name_alias: 'Alias' }
      }

      sp.reload
      assert_equal 'Original Name', sp.person_name
      assert_nil sp.name_alias
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

    test 'should update inline_history when person is not linked' do
      sp = snapshot_people(:three)
      assert_nil sp.person_id

      patch admin_unit_unit_snapshot_snapshot_person_path(@unit, sp.unit_snapshot, sp), params: {
        snapshot_person: { part: sp.part, sort_order: sp.sort_order, inline_history: 'edited history' }
      }

      assert_equal 'edited history', sp.reload.inline_history
    end

    test 'should not update inline_history when person is linked' do
      sp = snapshot_people(:one)
      assert sp.person_id.present?

      patch admin_unit_unit_snapshot_snapshot_person_path(@unit, sp.unit_snapshot, sp), params: {
        snapshot_person: { part: sp.part, sort_order: sp.sort_order, inline_history: 'edited history' }
      }

      assert_nil sp.reload.inline_history
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

    test 'renders edit form for linked snapshot_person with locked inline_history' do
      sp = snapshot_people(:one)
      assert sp.person_id.present?

      get edit_admin_unit_unit_snapshot_snapshot_person_path(@unit, sp.unit_snapshot, sp)

      assert_response :success
      assert_select 'a', text: /紐付け済み/
      assert_select 'textarea[name=?][readonly]', 'snapshot_person[inline_history]'
    end

    test 'renders edit form for unlinked snapshot_person with editable inline_history' do
      sp = snapshot_people(:three)
      assert_nil sp.person_id

      get edit_admin_unit_unit_snapshot_snapshot_person_path(@unit, sp.unit_snapshot, sp)

      assert_response :success
      assert_select 'span', text: /未紐付け/
      assert_select 'textarea[name=?]:not([readonly])', 'snapshot_person[inline_history]'
    end

    test 'renders edit form with single unified name field' do
      sp = snapshot_people(:one)

      get edit_admin_unit_unit_snapshot_snapshot_person_path(@unit, sp.unit_snapshot, sp)

      assert_response :success
      assert_select 'input[name=?]', 'snapshot_person[person_name]'
      assert_select 'input[name=?]', 'snapshot_person[name_alias]', count: 0
    end

    test 'renders add member form on unit_snapshot edit page' do
      get edit_admin_unit_unit_snapshot_path(@unit, @snapshot)

      assert_response :success
      assert_select 'h3', text: 'メンバーを追加'
    end

    test 'should copy selected members to another snapshot in the same unit' do
      sp = snapshot_people(:one)
      target = unit_snapshots(:two)

      assert_difference('SnapshotPerson.kept.count', 1) do
        post copy_or_move_admin_unit_unit_snapshot_snapshot_people_path(@unit, @snapshot), params: {
          mode: 'copy', target_unit_snapshot_id: target.id, snapshot_person_ids: [sp.id]
        }
      end

      assert_redirected_to edit_admin_unit_unit_snapshot_path(@unit, @snapshot)
      assert sp.reload.kept?
      copied = target.snapshot_people.find_by(person_id: sp.person_id)
      assert copied.present?
      assert_equal sp.part, copied.part
    end

    test 'should move selected members to another snapshot in the same unit' do
      sp = snapshot_people(:one)
      target = unit_snapshots(:two)

      assert_difference('SnapshotPerson.kept.count', 0) do
        post copy_or_move_admin_unit_unit_snapshot_snapshot_people_path(@unit, @snapshot), params: {
          mode: 'move', target_unit_snapshot_id: target.id, snapshot_person_ids: [sp.id]
        }
      end

      assert_redirected_to edit_admin_unit_unit_snapshot_path(@unit, @snapshot)
      assert_not sp.reload.kept?
      assert target.snapshot_people.find_by(person_id: sp.person_id).present?
    end

    test 'should not copy or move without selecting a target snapshot' do
      sp = snapshot_people(:one)

      assert_no_difference('SnapshotPerson.count') do
        post copy_or_move_admin_unit_unit_snapshot_snapshot_people_path(@unit, @snapshot), params: {
          mode: 'copy', target_unit_snapshot_id: '', snapshot_person_ids: [sp.id]
        }
      end

      assert_redirected_to edit_admin_unit_unit_snapshot_path(@unit, @snapshot)
    end

    test 'should not copy or move to a snapshot in another unit' do
      sp = snapshot_people(:one)
      other_unit_snapshot = unit_snapshots(:one).unit.unit_snapshots.create!(snapshot_date: '2030-01-01')
      other_unit_snapshot.update_column(:unit_id, units(:two).id)

      assert_no_difference('SnapshotPerson.count') do
        post copy_or_move_admin_unit_unit_snapshot_snapshot_people_path(@unit, @snapshot), params: {
          mode: 'copy', target_unit_snapshot_id: other_unit_snapshot.id, snapshot_person_ids: [sp.id]
        }
      end

      assert_redirected_to edit_admin_unit_unit_snapshot_path(@unit, @snapshot)
    end
  end
end
