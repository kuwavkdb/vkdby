# frozen_string_literal: true

require 'test_helper'

module Admin
  class TemporarySnapshotPeopleControllerTest < ActionDispatch::IntegrationTest
    setup do
      post login_path, params: { email: users(:one).email, password: 'password' }
      @unit = units(:one)
      @snapshot = unit_snapshots(:one)
      @other_snapshot = unit_snapshots(:two)
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

    test 'should prefill the name field with the resolved name when person_name is blank' do
      linked = TemporarySnapshotPerson.create!(
        person: people(:one),
        part: :vocal,
        status: :left,
        hint_unit: @unit
      )

      get assign_admin_temporary_snapshot_person_path(linked)
      assert_response :success
      assert_select 'input#person_name[value=?]', people(:one).name
    end

    test 'should list assign target snapshots ordered by snapshot_index, matching the snapshot list order' do
      @snapshot.update!(snapshot_index: 2)
      @other_snapshot.update!(snapshot_index: 1)

      get assign_admin_temporary_snapshot_person_path(@temporary_snapshot_person)
      assert_response :success
      assert_operator response.body.index(@other_snapshot.display_label),
                      :<, response.body.index(@snapshot.display_label)
    end

    test 'should assign to an existing snapshot and remove from pool' do
      assert_difference('SnapshotPerson.count', 1) do
        assert_difference('TemporarySnapshotPerson.count', -1) do
          post assign_admin_temporary_snapshot_person_path(@temporary_snapshot_person), params: {
            unit_id: @unit.id,
            unit_snapshot_ids: [@snapshot.id],
            part: 'vocal',
            status: 'left'
          }
        end
      end

      assert_redirected_to admin_temporary_snapshot_people_path(
        assigned_unit_id: @unit.id, assigned_unit_snapshot_ids: [@snapshot.id]
      )
      assert_equal 'テスト太郎', @snapshot.reload.snapshot_people.last.person_name
    end

    test 'should override person_name with the value from the form when assigning' do
      post assign_admin_temporary_snapshot_person_path(@temporary_snapshot_person), params: {
        unit_id: @unit.id,
        unit_snapshot_ids: [@snapshot.id],
        person_name: '上書き太郎',
        part: 'vocal',
        status: 'left'
      }

      assert_equal '上書き太郎', @snapshot.reload.snapshot_people.last.person_name
    end

    test 'should save part_alias as blank when it is cleared in the form' do
      @temporary_snapshot_person.update!(part_alias: '旧名→新名')

      post assign_admin_temporary_snapshot_person_path(@temporary_snapshot_person), params: {
        unit_id: @unit.id,
        unit_snapshot_ids: [@snapshot.id],
        person_name: 'テスト太郎',
        part_alias: '',
        part: 'vocal',
        status: 'left'
      }

      assert_nil @snapshot.reload.snapshot_people.last.part_alias
    end

    test 'should save person_name as blank when it is cleared in the form for a linked person' do
      linked = TemporarySnapshotPerson.create!(
        person: people(:one),
        person_name: '旧表記',
        part: :vocal,
        status: :left,
        hint_unit: @unit
      )

      post assign_admin_temporary_snapshot_person_path(linked), params: {
        unit_id: @unit.id,
        unit_snapshot_ids: [@snapshot.id],
        person_name: '',
        part: 'vocal',
        status: 'left'
      }

      assigned = @snapshot.reload.snapshot_people.last
      assert_nil assigned.person_name
      assert_equal people(:one), assigned.person
    end

    test 'should not assign when the name is cleared and no person is linked' do
      assert_no_difference('SnapshotPerson.count') do
        assert_no_difference('TemporarySnapshotPerson.count') do
          post assign_admin_temporary_snapshot_person_path(@temporary_snapshot_person), params: {
            unit_id: @unit.id,
            unit_snapshot_ids: [@snapshot.id],
            person_name: '',
            part: 'vocal',
            status: 'left'
          }
        end
      end

      assert_response :unprocessable_entity
    end

    test 'should append assigned member to the end of existing members' do
      max_sort_order = @snapshot.snapshot_people.maximum(:sort_order)

      post assign_admin_temporary_snapshot_person_path(@temporary_snapshot_person), params: {
        unit_id: @unit.id,
        unit_snapshot_ids: [@snapshot.id],
        create_new_snapshot: '1',
        part: 'vocal',
        status: 'left'
      }

      assert_equal max_sort_order + 1, @snapshot.reload.snapshot_people.last.sort_order
      assert_equal 1, UnitSnapshot.last.snapshot_people.last.sort_order
    end

    # issue #1654: Personに紐付いたメンバーを振り分けたとき、sns を Person#links にマージする
    test 'should merge sns into the linked person links when assigning to multiple snapshots' do
      linked = TemporarySnapshotPerson.create!(
        person: people(:one), part: :vocal, status: :left, hint_unit: @unit, sns: ['@pooled']
      )

      assert_difference({ 'people(:one).links.count' => 1, 'UpdateLog.where(loggable_type: "Link").count' => 1 }) do
        post assign_admin_temporary_snapshot_person_path(linked), params: {
          unit_id: @unit.id,
          unit_snapshot_ids: [@snapshot.id, @other_snapshot.id],
          part: 'vocal',
          status: 'left'
        }
      end

      assert_equal 'https://x.com/pooled', people(:one).links.last.url
    end

    test 'should carry over old_person_key when assigning' do
      @temporary_snapshot_person.update!(old_person_key: '旧キー太郎')

      post assign_admin_temporary_snapshot_person_path(@temporary_snapshot_person), params: {
        unit_id: @unit.id,
        unit_snapshot_ids: [@snapshot.id],
        part: 'vocal',
        status: 'left'
      }

      assert_equal '旧キー太郎', @snapshot.reload.snapshot_people.last.old_person_key
    end

    test 'should assign to multiple snapshots at once' do
      assert_difference('SnapshotPerson.count', 2) do
        assert_difference('TemporarySnapshotPerson.count', -1) do
          post assign_admin_temporary_snapshot_person_path(@temporary_snapshot_person), params: {
            unit_id: @unit.id,
            unit_snapshot_ids: [@snapshot.id, @other_snapshot.id],
            part: 'vocal',
            status: 'left'
          }
        end
      end

      assert_equal 'テスト太郎', @snapshot.reload.snapshot_people.last.person_name
      assert_equal 'テスト太郎', @other_snapshot.reload.snapshot_people.last.person_name
    end

    test 'should show links to all assigned unit snapshots after assigning' do
      post assign_admin_temporary_snapshot_person_path(@temporary_snapshot_person), params: {
        unit_id: @unit.id,
        unit_snapshot_ids: [@snapshot.id, @other_snapshot.id],
        part: 'vocal',
        status: 'left'
      }
      follow_redirect!

      assert_response :success
      assert_select "a[href='#{edit_admin_unit_unit_snapshot_path(@unit, @snapshot)}']"
      assert_select "a[href='#{edit_admin_unit_unit_snapshot_path(@unit, @other_snapshot)}']"
    end

    test 'should assign to a newly created snapshot when create_new_snapshot is checked' do
      assert_difference('UnitSnapshot.count', 1) do
        post assign_admin_temporary_snapshot_person_path(@temporary_snapshot_person), params: {
          unit_id: @unit.id,
          create_new_snapshot: '1',
          part: 'vocal',
          status: 'left'
        }
      end

      assert_redirected_to admin_temporary_snapshot_people_path(
        assigned_unit_id: @unit.id, assigned_unit_snapshot_ids: [UnitSnapshot.last.id]
      )
    end

    test 'should combine an existing snapshot and a newly created one' do
      assert_difference('UnitSnapshot.count', 1) do
        assert_difference('SnapshotPerson.count', 2) do
          post assign_admin_temporary_snapshot_person_path(@temporary_snapshot_person), params: {
            unit_id: @unit.id,
            unit_snapshot_ids: [@snapshot.id],
            create_new_snapshot: '1',
            part: 'vocal',
            status: 'left'
          }
        end
      end
    end

    test 'should not assign without selecting any snapshot' do
      assert_no_difference('SnapshotPerson.count') do
        post assign_admin_temporary_snapshot_person_path(@temporary_snapshot_person), params: {
          unit_id: @unit.id,
          part: 'vocal',
          status: 'left'
        }
      end
      assert_response :unprocessable_entity
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

    test 'should order by created_at by default' do
      zunit = Unit.create!(name: 'Zユニット', key: 'z-unit')
      later = TemporarySnapshotPerson.create!(person_name: 'あとから追加', part: :vocal, status: :left, hint_unit: zunit)

      get admin_temporary_snapshot_people_path
      assert_response :success
      assert_operator response.body.index(@temporary_snapshot_person.name),
                      :<, response.body.index(later.name)
    end

    test 'should order by hint unit name when sort=hint_unit' do
      aunit = Unit.create!(name: 'Aユニット', key: 'a-unit')
      earlier_by_unit = TemporarySnapshotPerson.create!(
        person_name: 'ユニット順で先頭', part: :vocal, status: :left, hint_unit: aunit
      )

      get admin_temporary_snapshot_people_path(sort: 'hint_unit')
      assert_response :success
      assert_operator response.body.index(earlier_by_unit.name),
                      :<, response.body.index(@temporary_snapshot_person.name)
    end
  end
end
