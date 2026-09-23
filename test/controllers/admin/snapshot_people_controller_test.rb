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

    test 'should carry over inline_history to person old_history when creating person' do
      sp = @snapshot.snapshot_people.create!(
        person_name: 'History Guy', part: 'vocal', person_key: 'history_test_key',
        inline_history: "2020/01 加入\n2021/01 脱退"
      )

      assert_difference('Person.count', 1) do
        post create_person_admin_unit_unit_snapshot_snapshot_person_path(@unit, @snapshot, sp)
      end

      sp.reload
      assert_equal "2020/01 加入\n2021/01 脱退", sp.person.old_history
    end

    # issue #1619: extra_profile（誕生日・生年・血液型・出身地の下書き）をPerson独立化時に自動コピーする
    test 'should carry over extra_profile to person when creating person' do
      sp = @snapshot.snapshot_people.create!(
        person_name: 'Profile Guy', part: 'vocal', person_key: 'profile_test_key',
        extra_profile: { 'birthday' => '7/12', 'birth_year' => 1990, 'blood' => 'AB', 'hometown' => '東京都' }
      )

      assert_difference('Person.count', 1) do
        post create_person_admin_unit_unit_snapshot_snapshot_person_path(@unit, @snapshot, sp)
      end

      sp.reload
      assert_equal Date.new(Person::DUMMY_BIRTH_YEAR, 7, 12), sp.person.birthday
      assert_equal 1990, sp.person.birth_year
      assert_equal 'AB', sp.person.blood
      assert_equal '東京都', sp.person.hometown
    end

    # issue #1653: sns（"@handle"形式・URL）をPerson独立化時にPerson#linksとして引き継ぐ
    test 'should carry over sns to person links when creating person' do
      sp = @snapshot.snapshot_people.create!(
        person_name: 'Sns Guy', part: 'vocal', person_key: 'sns_test_key',
        sns: ['@sns_guy', 'https://www.instagram.com/sns_guy/']
      )

      assert_difference({ 'Person.count' => 1, 'Link.count' => 2 }) do
        post create_person_admin_unit_unit_snapshot_snapshot_person_path(@unit, @snapshot, sp)
      end

      links = sp.reload.person.links.order(:sort_order)
      assert_equal ['https://x.com/sns_guy', 'https://www.instagram.com/sns_guy/'], links.map(&:url)
      assert_equal [1, 2], links.map(&:sort_order)
    end

    # issue #1654: 既存Personへ手動で紐付けたとき、sns を Person#links にマージし UpdateLog に記録する
    test 'should merge sns into existing person links and log them when linking a person' do
      sp = @snapshot.snapshot_people.create!(person_name: 'Link Me', part: 'vocal', sns: ['@link_me'])
      person = people(:one)

      assert_difference({ 'person.links.count' => 1, 'UpdateLog.where(loggable_type: "Link").count' => 1 }) do
        patch admin_unit_unit_snapshot_snapshot_person_path(@unit, @snapshot, sp), params: {
          snapshot_person: { person_id: person.id, person_name: 'Link Me', part: 'vocal' }
        }
      end

      link = person.links.last
      assert_equal 'https://x.com/link_me', link.url
      log = UpdateLog.find_by(loggable: link)
      assert_equal 'create', log.action
      assert_equal person, log.subject
    end

    test 'should create person without links when sns is blank' do
      sp = @snapshot.snapshot_people.create!(
        person_name: 'No Sns Guy', part: 'vocal', person_key: 'no_sns_test_key', sns: nil
      )

      assert_difference('Person.count', 1) do
        assert_no_difference('Link.count') do
          post create_person_admin_unit_unit_snapshot_snapshot_person_path(@unit, @snapshot, sp)
        end
      end

      assert_empty sp.reload.person.links
    end

    test 'should skip unparsable extra_profile birthday without failing person creation' do
      sp = @snapshot.snapshot_people.create!(
        person_name: 'Bad Birthday Guy', part: 'vocal', person_key: 'bad_birthday_test_key',
        extra_profile: { 'birthday' => '不明', 'blood' => 'O' }
      )

      assert_difference('Person.count', 1) do
        post create_person_admin_unit_unit_snapshot_snapshot_person_path(@unit, @snapshot, sp)
      end

      sp.reload
      assert_nil sp.person.birthday
      assert_equal 'O', sp.person.blood
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

    test 'should update extra_profile when person is not linked' do
      sp = snapshot_people(:three)
      assert_nil sp.person_id

      patch admin_unit_unit_snapshot_snapshot_person_path(@unit, sp.unit_snapshot, sp), params: {
        snapshot_person: {
          part: sp.part, sort_order: sp.sort_order,
          extra_profile: { birthday: '3/4', birth_year: '1995', blood: 'B', hometown: '大阪府' }
        }
      }

      sp.reload
      assert_equal(
        { 'birthday' => '3/4', 'birth_year' => '1995', 'blood' => 'B', 'hometown' => '大阪府' },
        sp.extra_profile
      )
    end

    test 'should not update extra_profile when person is linked' do
      sp = snapshot_people(:one)
      assert sp.person_id.present?

      patch admin_unit_unit_snapshot_snapshot_person_path(@unit, sp.unit_snapshot, sp), params: {
        snapshot_person: {
          part: sp.part, sort_order: sp.sort_order,
          extra_profile: { birthday: '3/4', blood: 'B' }
        }
      }

      assert_nil sp.reload.extra_profile
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

    test 'renders edit form with editable extra_profile fields when person is not linked' do
      sp = snapshot_people(:three)
      assert_nil sp.person_id

      get edit_admin_unit_unit_snapshot_snapshot_person_path(@unit, sp.unit_snapshot, sp)

      assert_response :success
      assert_select 'input[name=?]:not([disabled])', 'snapshot_person[extra_profile][birthday]'
      assert_select 'input[name=?]:not([disabled])', 'snapshot_person[extra_profile][birth_year]'
      assert_select 'input[name=?]:not([disabled])', 'snapshot_person[extra_profile][hometown]'
    end

    test 'renders edit form with disabled extra_profile fields when person is linked' do
      sp = snapshot_people(:one)
      assert sp.person_id.present?

      get edit_admin_unit_unit_snapshot_snapshot_person_path(@unit, sp.unit_snapshot, sp)

      assert_response :success
      assert_select 'input[name=?][disabled]', 'snapshot_person[extra_profile][birthday]'
    end

    test 'shows extra_profile in the person creation confirmation message' do
      sp = @snapshot.snapshot_people.create!(
        person_name: 'Confirm Guy', part: 'vocal', person_key: 'confirm_test_key',
        extra_profile: { 'birthday' => '7/12', 'hometown' => '東京都' }
      )

      get edit_admin_unit_unit_snapshot_snapshot_person_path(@unit, sp.unit_snapshot, sp)

      assert_response :success
      assert_includes response.body, '誕生日「7/12」'
      assert_includes response.body, '出身地「東京都」'
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
