# frozen_string_literal: true

require 'test_helper'

module Admin
  class UnitSnapshotsControllerTest < ActionDispatch::IntegrationTest # rubocop:disable Metrics/ClassLength
    setup do
      post login_path, params: { email: users(:one).email, password: 'password' }
      @unit = units(:one)
      @snapshot = unit_snapshots(:one)
    end

    test 'should get index' do
      get admin_unit_unit_snapshots_path(@unit)
      assert_response :success
    end

    test 'should list snapshots ordered to match the unit page and show RELATED badge for past snapshots' do
      other_snapshot = unit_snapshots(:two)
      @snapshot.update!(past: true, snapshot_index: 1)
      other_snapshot.update!(past: false, snapshot_index: 2)

      get admin_unit_unit_snapshots_path(@unit)
      assert_response :success
      assert_operator response.body.index(other_snapshot.display_label),
                      :<, response.body.index(@snapshot.display_label)
      assert_match 'RELATED', response.body
    end

    test 'edit links to the unit edit page and the snapshot on the public unit page, and warns when inactive (issue #1761)' do
      get edit_admin_unit_unit_snapshot_path(@unit, @snapshot)
      assert_response :success
      assert_includes response.body, profile_path(@unit.key, anchor: "snapshot-#{@snapshot.id}")
      # 同じタブで開く（issue #1818）
      assert_select 'a[href=?]', profile_path(@unit.key, anchor: "snapshot-#{@snapshot.id}"), text: /公開ページで確認/ do |links|
        assert_nil links.first['target']
      end
      assert_select 'h1 a[href=?]', edit_admin_unit_path(@unit)
      assert_not_includes response.body, '非公開のため、公開ページには表示されません'

      @snapshot.update!(active: false)
      get edit_admin_unit_unit_snapshot_path(@unit, @snapshot)
      assert_includes response.body, '非公開のため、公開ページには表示されません'
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

    # issue #1833: SNSはスナップショットメンバー側を常に表示し、誕生日・経歴はPerson未紐付けのときだけ表示する
    test 'edit lists member sns, and birthday and history only for unlinked members' do
      @snapshot.snapshot_people.create!(person_name: '未紐付けメンバー', part: :vocal,
                                        sns: ['@unlinked_handle'],
                                        extra_profile: { 'birthday' => '7/12' },
                                        inline_history: '2020/01 加入')
      @snapshot.snapshot_people.create!(person: people(:one), part: :guitar,
                                        sns: ['https://www.instagram.com/linked_member'],
                                        extra_profile: { 'birthday' => '3/4' },
                                        inline_history: '紐付け済みの経歴')

      get edit_admin_unit_unit_snapshot_path(@unit, @snapshot)

      assert_response :success
      assert_select 'a[href=?]', 'https://x.com/unlinked_handle'
      assert_select 'a[href=?]', 'https://www.instagram.com/linked_member'
      assert_includes response.body, '誕生日: 7月12日'
      assert_includes response.body, '2020/01 加入'
      assert_not_includes response.body, '3月4日'
      assert_not_includes response.body, '紐付け済みの経歴'
      assert_select 'span', text: '紐付け済み', count: @snapshot.snapshot_people.where.not(person_id: nil).count
      assert_select 'th', text: 'ステータス', count: 0
    end

    test 'should update unit_snapshot' do
      patch admin_unit_unit_snapshot_path(@unit, @snapshot), params: {
        unit_snapshot: { label: 'Updated Label', past: true }
      }
      assert_redirected_to admin_unit_unit_snapshots_path(@unit)
      @snapshot.reload
      assert_equal 'Updated Label', @snapshot.label
      assert @snapshot.past?
    end

    test 'should destroy unit_snapshot' do
      assert_difference('UnitSnapshot.count', -1) do
        delete admin_unit_unit_snapshot_path(@unit, @snapshot)
      end
      assert_redirected_to admin_unit_unit_snapshots_path(@unit)
    end

    test 'should copy unit_snapshot within the same unit and clear snapshot_date' do
      assert_difference('UnitSnapshot.count', 1) { post copy_admin_unit_unit_snapshot_path(@unit, @snapshot) }
      assert_nil UnitSnapshot.last.snapshot_date
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
