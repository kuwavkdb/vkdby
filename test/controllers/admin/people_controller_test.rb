# frozen_string_literal: true

require 'test_helper'

module Admin
  class PeopleControllerTest < ActionDispatch::IntegrationTest # rubocop:disable Metrics/ClassLength
    setup do
      post login_path, params: { email: users(:one).email, password: 'password' }
      @person = Person.create!(name: 'Existing Person', key: 'existing-person-controller-test', status: :active)
    end

    test 'search finds a person whose name is half-width when queried with full-width alphanumerics' do
      Person.create!(name: 'ABC123', key: 'zenkaku-search-admin-people-test', status: :active)

      get search_admin_people_path(q: 'ＡＢＣ１２３')

      assert_response :success
      assert_includes response.parsed_body.pluck('name'), 'ABC123'
    end

    test 'search includes a history summary to distinguish same-named people' do
      Person.create!(
        name: '同名太郎', key: 'history-summary-search-test', status: :active,
        old_history: '[[サンプルユニット]](Vocal)'
      )

      get search_admin_people_path(q: '同名太郎')

      assert_response :success
      result = response.parsed_body.find { |p| p['key'] == 'history-summary-search-test' }
      assert_equal 'サンプルユニット(Vocal)', result['history_summary']
    end

    test 'search history summary skips a trailing status-only tag with no unit name' do
      Person.create!(
        name: '状況不明太郎', key: 'history-summary-status-tag-test', status: :active,
        old_history: '[[サンプルユニット]](Vocal) → {{category 個人/状況不明}}'
      )

      get search_admin_people_path(q: '状況不明太郎')

      assert_response :success
      result = response.parsed_body.find { |p| p['key'] == 'history-summary-status-tag-test' }
      assert_equal 'サンプルユニット(Vocal)', result['history_summary']
    end

    test 'create allows setting key' do
      assert_difference('Person.count') do
        post admin_people_path, params: {
          person: { name: 'Brand New Person', key: 'brand-new-person-key', status: 'active' }
        }
      end

      assert_equal 'brand-new-person-key', Person.last.key
    end

    test 'update does not change key even when key param is submitted' do
      patch admin_person_path(@person), params: {
        person: { name: 'Renamed Person', key: 'attempted-new-key' }
      }

      assert_redirected_to edit_admin_person_path(@person)
      @person.reload
      assert_equal 'existing-person-controller-test', @person.key
      assert_equal 'Renamed Person', @person.name
    end

    test 'change_key requires admin role' do
      patch change_key_admin_person_path(@person), params: { new_key: 'attempted-new-key' }

      assert_redirected_to root_path
      assert_equal 'existing-person-controller-test', @person.reload.key
    end

    test 'change_key updates the key and creates a redirect stub when admin' do
      login_as_admin

      patch change_key_admin_person_path(@person), params: { new_key: 'new-person-key-via-endpoint' }

      assert_redirected_to edit_admin_person_path(@person)
      assert_nil flash[:alert]
      assert_equal 'Key changed successfully.', flash[:notice]
      assert_equal 'new-person-key-via-endpoint', @person.reload.key
      stub = Person.discarded.find_by(key: 'existing-person-controller-test')
      assert stub.present?
      assert_equal 'new-person-key-via-endpoint', stub.destination_key
      assert UpdateLog.exists?(loggable: @person, action: 'change_key')
    end

    test 'change_key shows an error when the new key is already taken' do
      login_as_admin
      Person.create!(name: 'Other Person', key: 'already-taken-person-key', status: :active)

      patch change_key_admin_person_path(@person), params: { new_key: 'already-taken-person-key' }

      assert_redirected_to edit_admin_person_path(@person)
      assert_equal 'existing-person-controller-test', @person.reload.key
    end

    test 'purge requires admin role' do
      @person.change_key!('new-key-for-purge-auth-test')
      stub = Person.discarded.find_by(key: 'existing-person-controller-test')

      delete purge_admin_person_path(stub)

      assert_redirected_to root_path
      assert Person.exists?(id: stub.id)
    end

    test 'purge is rejected for a record that is not discarded' do
      login_as_admin

      delete purge_admin_person_path(@person)

      assert_redirected_to admin_people_path(redirect_source: 'only')
      assert_equal '論理削除済みのレコードのみ物理削除できます。', flash[:alert]
      assert Person.exists?(id: @person.id)
    end

    test 'purge deletes the redirect-source stub and logs the action' do
      login_as_admin
      @person.change_key!('new-key-for-purge-test')
      stub = Person.discarded.find_by(key: 'existing-person-controller-test')

      delete purge_admin_person_path(stub)

      assert_redirected_to admin_people_path(redirect_source: 'only')
      assert_equal 'リダイレクト元レコードを物理削除しました。', flash[:notice]
      assert_not Person.exists?(id: stub.id)
      assert UpdateLog.exists?(loggable_type: 'Person', loggable_id: stub.id, action: 'purge')
    end

    test 'purge deletes a plain discarded record without a destination_key' do
      login_as_admin
      @person.discard

      delete purge_admin_person_path(@person)

      assert_redirected_to admin_people_path(redirect_source: 'only')
      assert_equal 'リダイレクト元レコードを物理削除しました。', flash[:notice]
      assert_not Person.exists?(id: @person.id)
      assert UpdateLog.exists?(loggable_type: 'Person', loggable_id: @person.id, action: 'purge')
    end

    test 'purge is rejected when the key is still referenced by an item' do
      login_as_admin
      @person.change_key!('new-key-for-purge-item-test')
      stub = Person.discarded.find_by(key: 'existing-person-controller-test')
      Item.create!(title: 'Some Album', release_date: Date.current, link_url: 'https://example.com/item',
                   artists: [{ 'key' => stub.key, 'name' => 'Existing Person' }])

      delete purge_admin_person_path(stub)

      assert_redirected_to admin_people_path(redirect_source: 'only')
      assert_equal 'このキーはまだ作品から参照されているため物理削除できません。', flash[:alert]
      assert Person.exists?(id: stub.id)
    end

    test 'purge is rejected when the key is still used as another redirect destination' do
      login_as_admin
      @person.discard
      Person.create!(name: 'Newer Person', key: 'newer-person-controller-test', status: :active,
                     destination_key: @person.key).discard

      delete purge_admin_person_path(@person)

      assert_redirected_to admin_people_path(redirect_source: 'only')
      assert_equal 'このキーはリダイレクト先として参照されているため物理削除できません。', flash[:alert]
      assert Person.exists?(id: @person.id)
    end

    test 'purge is rejected when the person is still linked via unit_people' do
      login_as_admin
      unit = Unit.create!(name: 'Some Band', key: 'some-band-purge-test', status: :active)
      unit.unit_people.create!(person: @person, status: :active, part: :vocal)
      @person.discard

      delete purge_admin_person_path(@person)

      assert_redirected_to admin_people_path(redirect_source: 'only')
      assert_equal 'ユニットのメンバー情報が残っているため物理削除できません。', flash[:alert]
      assert Person.exists?(id: @person.id)
    end

    test 'purge is rejected when the person is still linked via snapshot_people' do
      login_as_admin
      unit = Unit.create!(name: 'Some Band', key: 'some-band-snapshot-purge-test', status: :active)
      unit_snapshot = unit.unit_snapshots.create!(snapshot_date: Date.current)
      unit_snapshot.snapshot_people.create!(person: @person, status: :active, part: :vocal)
      @person.discard

      delete purge_admin_person_path(@person)

      assert_redirected_to admin_people_path(redirect_source: 'only')
      assert_equal 'ユニットスナップショットのメンバー情報が残っているため物理削除できません。', flash[:alert]
      assert Person.exists?(id: @person.id)
    end

    test 'purging a redirect-source stub allows reverting the key' do
      login_as_admin
      @person.change_key!('new-key-for-purge-revert-test')
      stub = Person.discarded.find_by(key: 'existing-person-controller-test')

      delete purge_admin_person_path(stub)
      @person.reload.change_key!('existing-person-controller-test')

      assert_equal 'existing-person-controller-test', @person.reload.key
    end

    test 'edit shows the change key form for admin' do
      login_as_admin

      get edit_admin_person_path(@person)

      assert_response :success
      assert_includes response.body, 'キー変更'
    end

    test 'edit does not show the change key form for non-admin' do
      get edit_admin_person_path(@person)

      assert_response :success
      assert_not_includes response.body, 'キー変更'
    end

    test 'index renders tag filter comboboxes only for groups and tags visible on people' do
      group = IndexGroup.create!(name: '属性グループ', people_filter_order: 1)
      hidden_group = IndexGroup.create!(name: '非表示グループ', people_filter_order: nil)
      TagIndex.create!(name: '有効タグ', index_group: group, order_in_group: 1)
      TagIndex.create!(name: '無効タグ', index_group: group, active: false)
      TagIndex.create!(name: '孤立タグ', index_group: hidden_group)

      get admin_people_path

      assert_response :success
      assert_includes response.body, '属性グループ'
      assert_includes response.body, '有効タグ'
      assert_not_includes response.body, '無効タグ'
      assert_not_includes response.body, '非表示グループ'
      assert_not_includes response.body, '孤立タグ'
    end

    test 'index filters people by tag_index_id selected from the tag filter' do
      group = IndexGroup.create!(name: '属性グループ', people_filter_order: 1)
      tag = TagIndex.create!(name: '有効タグ', index_group: group, order_in_group: 1)
      TagIndexItem.create!(tag_index: tag, indexable: @person)
      other_person = Person.create!(name: 'Other Person', key: 'other-person-controller-test', status: :active)

      get admin_people_path(tag_index_id: tag.id)

      assert_response :success
      assert_includes response.body, @person.name
      assert_not_includes response.body, other_person.name
    end

    test 'index filters people by status' do
      hiatus_person = Person.create!(name: 'Hiatus Person', key: 'hiatus-person-controller-test', status: :hiatus)

      get admin_people_path(status: 'hiatus')

      assert_response :success
      assert_includes response.body, hiatus_person.name
      assert_not_includes response.body, @person.name
    end

    test 'index combines tag_index_id and status filters' do
      group = IndexGroup.create!(name: '属性グループ', people_filter_order: 1)
      tag = TagIndex.create!(name: '有効タグ', index_group: group, order_in_group: 1)
      tagged_active = Person.create!(name: 'Tagged Active Person', key: 'tagged-active-person-test', status: :active)
      tagged_hiatus = Person.create!(name: 'Tagged Hiatus Person', key: 'tagged-hiatus-person-test', status: :hiatus)
      TagIndexItem.create!(tag_index: tag, indexable: tagged_active)
      TagIndexItem.create!(tag_index: tag, indexable: tagged_hiatus)

      get admin_people_path(tag_index_id: tag.id, status: 'hiatus')

      assert_response :success
      assert_includes response.body, tagged_hiatus.name
      assert_not_includes response.body, tagged_active.name
    end

    test 'bulk_update_status requires admin role' do
      other_person = Person.create!(name: 'Other Person', key: 'bulk-status-auth-person', status: :active)

      patch bulk_update_status_admin_people_path, params: { ids: [@person.id, other_person.id], status: 'hiatus' }

      assert_redirected_to root_path
      assert_equal 'active', @person.reload.status
      assert_equal 'active', other_person.reload.status
    end

    test 'bulk_update_status updates the status of the selected people and logs each change' do
      login_as_admin
      other_person = Person.create!(name: 'Other Person', key: 'bulk-status-person', status: :active)

      patch bulk_update_status_admin_people_path, params: { ids: [@person.id, other_person.id], status: 'hiatus' }

      assert_redirected_to admin_people_path
      assert_equal '2件のStatusを更新しました', flash[:notice]
      assert_equal 'hiatus', @person.reload.status
      assert_equal 'hiatus', other_person.reload.status
      assert UpdateLog.exists?(loggable: @person, action: 'update')
      assert UpdateLog.exists?(loggable: other_person, action: 'update')
    end

    test 'bulk_update_status shows an alert when no ids are selected' do
      login_as_admin

      patch bulk_update_status_admin_people_path, params: { ids: [], status: 'hiatus' }

      assert_redirected_to admin_people_path
      assert_equal '項目が選択されていません', flash[:alert]
    end

    test 'bulk_update_status shows an alert for an invalid status' do
      login_as_admin

      patch bulk_update_status_admin_people_path, params: { ids: [@person.id], status: 'not-a-real-status' }

      assert_redirected_to admin_people_path
      assert_equal 'Statusを選択してください', flash[:alert]
      assert_equal 'active', @person.reload.status
    end

    private

    def login_as_admin
      admin = User.create!(email: 'admin-key-change-test@example.com', name: 'Admin', password: 'password', role: :admin)
      post login_path, params: { email: admin.email, password: 'password' }
    end
  end
end
