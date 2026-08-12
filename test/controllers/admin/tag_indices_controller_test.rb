# frozen_string_literal: true

require 'test_helper'

module Admin
  class TagIndicesControllerTest < ActionDispatch::IntegrationTest
    setup do
      post login_path, params: { email: users(:one).email, password: 'password' }
    end

    test 'create adds a tag to the specified group' do
      group = IndexGroup.create!(name: 'テストグループ', sort_order: 1)

      assert_difference('TagIndex.count') do
        post admin_tag_indices_path, params: {
          tag_index: { name: '新規タグ', index_group_id: group.id, active: true }
        }
      end

      tag_index = TagIndex.last
      assert_equal 'テストグループ', tag_index.index_group.name
      assert_redirected_to admin_index_group_path(group)
    end

    test 'create without a group leaves the tag unclassified' do
      assert_difference('TagIndex.count') do
        post admin_tag_indices_path, params: { tag_index: { name: '未分類タグ' } }
      end

      assert_nil TagIndex.last.index_group_id
      assert_redirected_to admin_index_group_path(id: 0)
    end

    test 'create rejects a duplicate name' do
      TagIndex.create!(name: '既存タグ')

      assert_no_difference('TagIndex.count') do
        post admin_tag_indices_path, params: { tag_index: { name: '既存タグ' } }
      end

      assert_response :unprocessable_entity
    end

    test 'update renames a tag' do
      tag_index = TagIndex.create!(name: '旧名')

      patch admin_tag_index_path(tag_index), params: { tag_index: { name: '新名' } }

      assert_redirected_to admin_index_groups_path
      assert_equal '新名', tag_index.reload.name
    end

    test 'update rejects renaming to a duplicate name' do
      TagIndex.create!(name: '重複タグ')
      tag_index = TagIndex.create!(name: '元の名前')

      patch admin_tag_index_path(tag_index), params: { tag_index: { name: '重複タグ' } }

      assert_response :unprocessable_entity
      assert_equal '元の名前', tag_index.reload.name
    end

    test 'destroy removes the tag and its items' do
      group = IndexGroup.create!(name: 'グループ', sort_order: 1)
      tag_index = TagIndex.create!(name: '削除対象', index_group: group)

      assert_difference('TagIndex.count', -1) do
        delete admin_tag_index_path(tag_index)
      end

      assert_redirected_to admin_index_group_path(group)
    end
  end
end
